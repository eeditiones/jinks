xquery version "3.1";

module namespace zotero = "http://e-editiones.org/edep/api/zotero";

declare namespace http     = "http://expath.org/ns/http-client";
declare namespace request  = "http://exist-db.org/xquery/request";
declare namespace response = "http://exist-db.org/xquery/response";
declare namespace xmldb    = "http://exist-db.org/xquery/xmldb";
declare namespace util     = "http://exist-db.org/xquery/util";
declare namespace tei      = "http://www.tei-c.org/ns/1.0";

import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";

(: ---- CONFIG: static values baked in at generation time ---- :)

declare variable $zotero:API_BASE  as xs:string := "[[ $context?features?zotero?api_base ]]";
declare variable $zotero:GROUP_ID  as xs:string := "[[ $context?features?zotero?group_id ]]";
declare variable $zotero:STYLE     as xs:string := "[[ $context?features?zotero?style ]]";
declare variable $zotero:API_KEY   as xs:string := "[[ $context?features?zotero?api_key ]]";

(: ---- CONFIG: paths derived at runtime from data-root and group-id ---- :)

declare variable $zotero:GROUP_BASE as xs:string :=
    $config:data-root || "/zotero/groups/" || $zotero:GROUP_ID;

declare variable $zotero:ITEMS_DIR    as xs:string := $zotero:GROUP_BASE || "/items";
declare variable $zotero:XML_DIR      as xs:string := $zotero:GROUP_BASE || "/items-xml";
declare variable $zotero:META_PATH    as xs:string := $zotero:GROUP_BASE || "/meta.json";

declare %private function zotero:mkcol-recursive($collection as xs:string, $components as xs:string*) as empty-sequence() {
  if (exists($components)) then
    let $newColl := concat($collection, "/", $components[1])
    let $_ :=
      if (not(xmldb:collection-available($newColl))) then
        xmldb:create-collection($collection, $components[1])
      else ()
    return
      zotero:mkcol-recursive($newColl, subsequence($components, 2))
  else ()
};

declare %private function zotero:ensure-collection-path($collPath as xs:string) as empty-sequence() {
  let $prefix := $config:data-root || "/"
  let $rel :=
    if (starts-with($collPath, $prefix)) then
      substring-after($collPath, $prefix)
    else
      $collPath
  return zotero:mkcol-recursive($config:data-root, tokenize($rel, "/"))
};

declare %private function zotero:ensure-collections() as empty-sequence() {
  let $_ := zotero:ensure-collection-path($zotero:ITEMS_DIR)
  let $_ := zotero:ensure-collection-path($zotero:XML_DIR)
  return ()
};

(: ====== HEADERS for Zotero HTTP requests ====== :)
declare %private function zotero:headers($extra as element(http:header)?) as element(http:header)* {
  let $base :=
    (<http:header name="Accept" value="application/json"/>,
     <http:header name="User-Agent" value="eXist/zotero-sync"/>,
     <http:header name="Accept-Encoding" value="identity"/>,
     (: IMPORTANT :)
     <http:header name="Zotero-API-Version" value="3"/>)
  let $auth :=
    if (normalize-space($zotero:API_KEY) ne "")
               then <http:header name="Zotero-API-Key" value="{ $zotero:API_KEY }"/>
               else ()
  return ($base, $auth, $extra)
};

declare function zotero:read-meta() as map(*) {
  let $log := util:log('info','read-meta file;' || $zotero:META_PATH)
  return
      let $bin   := util:binary-doc($zotero:META_PATH)
      let $txt   := util:binary-to-string($bin)
      return
          if ($txt ne "") then
            try {
                parse-json($txt)
            } catch * { map{ "libraryVersion": 0 } }
            else map{ "libraryVersion": 0 }
};

declare %private function zotero:write-meta($lv as xs:integer) as xs:boolean {
  let $coll := substring-before($zotero:META_PATH, concat("/", tokenize($zotero:META_PATH, "/")[last()]))
  let $name := tokenize($zotero:META_PATH, "/")[last()]
  return
    try {
      let $_ := xmldb:store(
        $coll,
        $name,
        serialize(
          map{ "libraryVersion": $lv, "syncedAt": current-dateTime() },
          map{ "method":"json", "indent": true() }
        ),
        "application/json"
      )
      return true()
    } catch * {
      false()
    }
};

declare %private function zotero:xml-from-json($data as map(*), $bib as xs:string?) as element(item) {
  let $type := $data?data?itemType
  let $key     := string(($data?key, $data?data?key)[1])
  let $title   := string(($data?title, $data?data?title)[1])
  let $shortTitle := string(($data?shortTitle, $data?data?shortTitle)[1])
  let $dt      := string(($data?dateModified, $data?data?dateModified)[1])
  let $creators     := if ($data?data?creators instance of array(*)) then $data?data?creators else array { $data?data?creators }
  let $tagsArr := $data?data?tags
  return
    <bibl xmlns="http://www.tei-c.org/ns/1.0" xml:id="{ $key }">
      <title>{ $title }</title>
      <title type="short">{ $shortTitle }</title>
      {
        switch ($type)
            case 'bookSection' return <title level="m">{ $data?data?bookTitle }</title>
            case 'journalArticle' case 'newspaperArticle' return (
                <title level="j">{ $data?data?publicationTitle }</title>,
                <title level="j" type="short">{ $data?data?journalAbbreviation }</title>
            )
            case 'bookChapter' return <title level="m">{ $data?data?title }</title>
            case 'encyclopediaArticle' return <title level="m">{ $data?data?encyclopediaTitle }</title>
            case 'webpage' return <title level="u">{ $data?data?websiteTitle }</title>
            default return ()
      }
      {
        if ($data?data?series) then <title level="s">{ $data?data?series }</title> else ()
      }
      {
        for $c in $creators?*
        return
          element { if ($c?creatorType = 'author') then 'author' else 'editor' } {
            string-join(($c?firstName, $c?lastName, $c?name), ' ')
          }
      }
      <pubPlace>{ $data?data?place }</pubPlace>
      <publisher>{ $data?data?publisher }</publisher>
      <date>{ $data?data?date }</date>
      <date type="modified" when="{ $dt }"/>
      {
        for $tag in if ($tagsArr instance of array(*)) then $tagsArr?* else $tagsArr
        return <term>{ $tag?tag }</term>
      }
      {
        if ($data?data?note) then <note>{ $data?data?note }</note> else ()
      }
      <note type="display">{ $bib }</note>
    </bibl>
};

declare %private function zotero:xml-upsert(
  $data as map(*),
  $bib  as xs:string?
) as empty-sequence() {
  let $key  := string(($data?key, $data?data?key)[1])
  let $xml  := zotero:xml-from-json($data, $bib)
  let $name := concat($key, ".xml")
  let $_    := xmldb:store($zotero:XML_DIR, $name, $xml, "application/xml")
  return ()
};

(: ====== Ingest one page of items from Zotero (array) ====== :)
declare %private function zotero:ingest-page($arr as array(*)) as xs:integer {
  let $n :=
    sum(
      for $i in 1 to array:size($arr)
      let $entry := array:get($arr, $i)
      let $key   := string(($entry?key, $entry?data?key)[1])
      let $data  := if ($entry?data instance of map(*)) then $entry?data else map{}
      let $bib   := string(($entry?bib)[1])
      let $json  := serialize(map{ "data": $data, "bib": $bib }, map{"method":"json"})
      let $_js   := xmldb:store($zotero:ITEMS_DIR, concat($key, ".json"), $json, "application/json")
      let $_xml  := zotero:xml-upsert(map{ "key": $key, "data": $data }, $bib)
      return 1
    )
  return $n
};

declare %private function zotero:_page-href(
  $since as xs:integer,
  $start as xs:integer
) as xs:string {
  let $AMP := codepoints-to-string(38)
  let $qs  := string-join((
               concat("since=",  encode-for-uri(string($since))),
               "limit=100",
               concat("start=", string($start)),
               "include=data,bib",
               "format=json",
               "sort=dateModified",
               "direction=asc",
               if (normalize-space($zotero:STYLE) ne "")
               then concat("style=", encode-for-uri($zotero:STYLE))
               else ()
             ), $AMP)
  return concat($zotero:API_BASE, "/groups/", $zotero:GROUP_ID, "/items?", $qs)
};

declare %private function zotero:_body-as-string($respSeq as item()*) as xs:string {
  if (empty($respSeq) or count($respSeq) lt 2) then ""
  else
    let $b := $respSeq[2]
    return
      if ($b instance of xs:base64Binary) then util:binary-to-string($b)
      else if ($b instance of document-node()) then string($b)
      else if ($b instance of node()) then string($b)
      else if ($b instance of xs:string) then $b
      else ""
};

declare %private function zotero:_first-href($since as xs:integer) as xs:string {
  let $AMP := codepoints-to-string(38)
  let $qs  := string-join((
               concat("since=",  encode-for-uri(string($since))),
               "limit=100",
               "include=data,bib",
               "format=json",
               "sort=dateModified",
               "direction=asc",
               if (normalize-space($zotero:STYLE) ne "")
               then concat("style=", encode-for-uri($zotero:STYLE))
               else ()
             ), $AMP)
  return concat($zotero:API_BASE, "/groups/", $zotero:GROUP_ID, "/items?", $qs)
};

declare %private function zotero:_fetch-first-page($since as xs:integer, $tries as xs:integer) as item()* {
  let $log0 := util:log('info','_fetch-first-page since:' || $since || ' tries:' || $tries)
  let $href := zotero:_first-href($since)
  let $req  :=
    <http:request method="GET">
      { attribute href { $href } }
      {
        zotero:headers(
          if ($since gt 0)
          then <http:header name="If-Modified-Since-Version" value="{ string($since) }"/>
          else ()
        )
      }
    </http:request>
  let $seq := try { http:send-request($req) } catch * { () }
  return
    if (empty($seq)) then ()
    else
      let $r := $seq[1]
      let $code := xs:integer($r/@status)
      return
        if (($code = 429 or $code = 500 or $code = 502 or $code = 503 or $code = 504) and $tries gt 0) then
          ( util:wait(max((zotero:_backoff-ms($r), 1500))),
            zotero:_fetch-first-page($since, $tries - 1) )
        else $seq
};

declare %private function zotero:_fetch-page-start(
  $since as xs:integer,
  $start as xs:integer
) as xs:integer {
  zotero:_fetch-page-start-retry($since, $start, 3, 0)
};

declare %private function zotero:_fetch-page-start-retry(
  $since   as xs:integer,
  $start   as xs:integer,
  $tries   as xs:integer,
  $attempt as xs:integer
) as xs:integer {
  let $href := zotero:_page-href($since, $start)
  let $req  :=
    <http:request method="GET">
      { attribute href { $href } }
      { zotero:headers(()) }
    </http:request>
  let $res := try { http:send-request($req) } catch * { () }
  return
    if (empty($res)) then 0
    else
      let $r1   := $res[1]
      let $code := xs:integer($r1/@status)
      return
        if ($code = 429 or $code = 500 or $code = 502 or $code = 503 or $code = 504) then
          let $base  := max( (zotero:_backoff-ms($r1), 1500) )
          let $jitter := 400 * (($attempt mod 3) + 1)
          let $delay := ($base * (1 + $attempt)) + $jitter
          let $log  := util:log('info', '[zotero] start=' || $start || ' status ' || $code || ' backoff=' || $delay)
          let $_wait := util:wait($delay)
          return
            if ($tries gt 0)
            then zotero:_fetch-page-start-retry($since, $start, $tries - 1, $attempt + 1)
            else ( util:log('warn', '[zotero] start=' || $start || ' giving up'), 0 )
        else if ($code != 200) then (
          util:log('warn', '[zotero] start=' || $start || ' http=' || $code),
          0
        )
        else
          let $raw   := zotero:_body-as-string($res)
          let $head  := normalize-space(substring($raw, 1, 200))
          let $isHtml := starts-with($head, "<")
          return
            if ($isHtml) then
              if ($tries gt 0)
              then ( util:log('warn', '[zotero] start=' || $start || ' got HTML, retrying'),
                     util:wait(1000),
                     zotero:_fetch-page-start-retry($since, $start, $tries - 1, $attempt + 1) )
              else ( util:log('warn', '[zotero] start=' || $start || ' got HTML, giving up'), 0 )
            else
              let $arr := if ($raw = "") then array{} else try { parse-json($raw) } catch * { array{} }
              return
                if ($arr instance of array(*)) then zotero:ingest-page($arr)
                else if ($tries gt 0)
                then ( util:log('warn', '[zotero] start=' || $start || ' parse-json failed; head=' || $head),
                       util:wait(1000),
                       zotero:_fetch-page-start-retry($since, $start, $tries - 1, $attempt + 1) )
                else ( util:log('warn', '[zotero] start=' || $start || ' parse-json failed, giving up; head=' || $head), 0 )
};

declare %private function zotero:_walk-by-start(
  $since  as xs:integer,
  $total  as xs:integer,
  $start0 as xs:integer
) as xs:integer {
  zotero:_walk-by-start-int($since, $total, $start0, 0, 0)
};

declare %private function zotero:_walk-by-start-int(
  $since     as xs:integer,
  $total     as xs:integer,
  $start     as xs:integer,
  $acc       as xs:integer,
  $stallRuns as xs:integer
) as xs:integer {
  let $chunk     := 100
  let $maxStalls := 5
  return
    if ($start ge $total) then $acc
    else
      let $cnt := zotero:_fetch-page-start($since, $start)
      return
        if ($cnt gt 0) then
          ( util:wait(250),
            zotero:_walk-by-start-int($since, $total, $start + $chunk, $acc + $cnt, 0) )
        else if ($stallRuns lt $maxStalls) then
          ( util:log('warn', '[zotero] start=' || $start || ' stalled (' || ($stallRuns + 1) || '/' || $maxStalls || '), retrying same start'),
            util:wait(1200 + (200 * $stallRuns)),
            zotero:_walk-by-start-int($since, $total, $start, $acc, $stallRuns + 1) )
        else
          ( util:log('warn', '[zotero] start=' || $start || ' stalled too often; skipping to next chunk'),
            zotero:_walk-by-start-int($since, $total, $start + $chunk, $acc, 0) )
};

declare %private function zotero:_backoff-ms($r as element(http:response)) as xs:integer {
  let $val1 := normalize-space(($r/http:header[lower-case(@name)='backoff']/@value)[1])
  let $val2 := normalize-space(($r/http:header[lower-case(@name)='retry-after']/@value)[1])
  let $sec1 := if ($val1 castable as xs:integer) then xs:integer($val1) else 0
  let $sec2 := if ($val2 castable as xs:integer) then xs:integer($val2) else 0
  return xs:integer(max(($sec1, $sec2, 0))) * 1000
};

declare function zotero:sync($request as map(*)) {
  response:set-header("Content-Type","application/json"),
  let $log0 := util:log('info','zotero sync started')
  let $_   := zotero:ensure-collections()
  let $meta  := zotero:read-meta()
  let $since := xs:integer( ($meta?libraryVersion, 0)[1] )
  let $log1  := util:log('info','libraryVersion ' || $since)
  let $user  := $request?user
  let $href  := zotero:_first-href($since)
  let $logH  := util:log('info','HREF ' || $href)
  let $respSeq := zotero:_fetch-first-page($since, 3)
  return
    if (empty($respSeq)) then
      serialize(map{
        "status":"error",
        "reason":"http:send-request failed",
        "requestHref": $href
      }, map{"method":"json","indent":true()})
    else
      let $resp   := $respSeq[1]
      let $status := xs:integer($resp/@status)
      let $logS   := util:log('info','zotero response status ' || $status)
      return
        if ($status = 304) then (
          let $meta := zotero:write-meta($since)
          return
          map{
            "status":"ok",
            "updated": 0,
            "libraryVersion": $since,
            "totalResults": 0
          }
        )
        else if ($status != 200) then
          let $err := try { util:binary-to-string($respSeq[2]) } catch * { "" }
          return serialize(map{
            "status":"error",
            "httpStatus": $status,
            "errorBody": $err,
            "requestHref": $href
          }, map{"method":"json","indent":true()})
        else
          let $raw    := try { util:binary-to-string($respSeq[2]) } catch * { "" }
          let $clean  := if (starts-with($raw, codepoints-to-string(65279))) then substring($raw, 2) else $raw
          let $arr    := if (normalize-space($clean) = "") then array{} else try { parse-json($clean) } catch * { array{} }
          let $totalStr := ($resp/http:header[lower-case(@name)='total-results']/@value)[1]
          let $total    := if ($totalStr and normalize-space($totalStr) ne "") then xs:integer($totalStr) else 0
          let $c1 :=
            if ($arr instance of array(*)) then
              sum(
                for $i in 1 to array:size($arr)
                let $entry := array:get($arr, $i)
                let $key   := string(($entry?key, $entry?data?key)[1])
                let $data  := if ($entry?data instance of map(*)) then $entry?data else map{}
                let $bib   := string(($entry?bib)[1])
                let $json  := serialize(map{ "data": $data, "bib": $bib }, map{"method":"json"})
                let $_j    := xmldb:store($zotero:ITEMS_DIR, concat($key, ".json"), $json, "application/json")
                let $_x    := zotero:xml-upsert(map{ "key": $key, "data": $data }, $bib)
                return 1
              )
            else 0
          let $cN :=
            if ($total gt $c1)
            then zotero:_walk-by-start($since, $total, $c1)
            else 0
          let $lmvStr := ($resp/http:header[lower-case(@name)='last-modified-version']/@value)[1]
          let $lmv    := if ($lmvStr and normalize-space($lmvStr) ne "") then xs:integer($lmvStr) else $since
          let $_m     := zotero:write-meta($lmv)
          return map{
            "status":"ok",
            "updated": $c1 + $cN,
            "libraryVersion": $lmv,
            "totalResults": $total
          }
};

declare %private function zotero:strip-diacritics($str as xs:string) as xs:string {
  let $decomposed := normalize-unicode($str, "NFD")
  let $stripped := string-join(
    for $cp in string-to-codepoints($decomposed)
    where $cp lt 768 or $cp gt 879
    return codepoints-to-string($cp)
  )
  return normalize-unicode($stripped, "NFC")
};

declare %private function zotero:_lucene-escape($s as xs:string) as xs:string {
  let $t0 := replace($s, "\\", "\\\\")
  let $t1 := replace($t0, "([+\-!(){}\[\]\^""~\?:/])", "\\\$1")
  return $t1
};

declare %private function zotero:_lucene-wildcard-and($raw as xs:string) as xs:string? {
  let $norm :=
    lower-case(zotero:strip-diacritics(normalize-space($raw)))
  let $flat := replace($norm, "[,;]+", " ")
  let $terms :=
    for $w in tokenize($flat, "\s+")
    let $w2 := normalize-space($w)
    where $w2 ne ""
    return $w2
  return
    if (empty($terms)) then ()
    else
      string-join(
        for $t in $terms
        let $e := zotero:_lucene-escape($t)
        return concat("bibl-content:*", $e, "*"),
        " AND "
      )
};

declare %private function zotero:_lucene-prefix-and($raw as xs:string) as xs:string? {
  let $norm :=
    lower-case(zotero:strip-diacritics(normalize-space($raw)))
  let $flat := replace($norm, "[,;]+", " ")
  let $terms :=
    for $w in tokenize($flat, "\s+")
    let $w2 := normalize-space($w)
    where $w2 ne ""
    return $w2
  return
    if (empty($terms)) then ()
    else
      "bibl-content:(" ||
      string-join(
        for $t in $terms
        let $e := zotero:_lucene-escape($t)
        return concat($e, "*"),
        " AND "
      )
      || ")"
};

declare function zotero:items-suggest($request as map(*)) {
  response:set-header("Content-Type", "application/json"),
  let $qRaw  := request:get-parameter("q", "")
  let $tag   := normalize-space(request:get-parameter("tag", ""))
  let $limit := let $l := number(request:get-parameter("limit", "8"))
                return if ($l ge 1) then xs:integer($l) else 8
  let $qry := if ($tag ne "") then () else zotero:_lucene-wildcard-and($qRaw)
  let $pool :=
    if ($tag ne "") then
      collection($zotero:XML_DIR)/tei:bibl[tei:title[@type='short'] = $tag]
    else if (empty($qry)) then
      ()
    else
      collection($zotero:XML_DIR)/tei:bibl[
        ft:query(., $qry, map{
          "leading-wildcard": "yes",
          "filter-rewrite": "yes",
          "query-analyzer-id": "nodiacritics"
        })
      ]
  let $sorted :=
    if ($tag ne "" or empty($qry)) then
      for $i in $pool
      order by xs:dateTime($i/tei:date[@type='modified']/@when) descending
      return $i
    else
      for $i in $pool
      let $score := ft:score($i)
      order by $score descending,
               xs:dateTime($i/tei:date[@type='modified']/@when) descending
      return $i
  let $picked := subsequence($sorted, 1, $limit)
  let $arr := array {
    for $i in $picked
    return map{
      "key":   string($i/@xml:id),
      "title": string($i/tei:title[not(@type|@level)][1]),
      "bib":   string(($i/tei:note[@type='display'])[1]),
      "tag":   string(($i/tei:title[@type='short'])[1])
    }
  }
  return serialize($arr, map{ "method":"json", "indent": true() })
};

declare function zotero:items-search($request as map(*)) {
  response:set-header("Content-Type", "application/json"),
  let $q     := lower-case(normalize-space(request:get-parameter("q", "")))
  let $tag   := lower-case(normalize-space(request:get-parameter("tag", "")))
  let $limit := let $l := number(request:get-parameter("limit", "15")) return if ($l ge 1) then xs:integer($l) else 15
  let $pool :=
    collection($zotero:XML_DIR)/item[
      ( $q = "" or ft:query(., $q) )
      and ( $tag = "" or tags/tag = $tag )
    ]
  let $sorted := for $i in $pool order by xs:dateTime($i/@dateModified) descending return $i
  let $total  := count($sorted)
  let $picked := subsequence($sorted, 1, $limit)
  let $items := array {
    for $i in $picked
    let $key := string($i/@key)
    let $bin := util:binary-doc(concat($zotero:ITEMS_DIR, "/", $key, ".json"))
    let $txt := if ($bin) then util:binary-to-string($bin) else ""
    let $obj := if ($txt ne "") then try { parse-json($txt) } catch * { () } else ()
    return
      if ($obj instance of map(*)) then map{ "key": $key, "data": ($obj?data, $obj)[1] }
      else                           map{ "key": $key, "data": map{} }
  }
  return serialize(map{
    "query":    map{ "q": $q, "tag": $tag, "limit": $limit },
    "total":    $total,
    "returned": array:size($items),
    "items":    $items
  }, map{ "method":"json", "indent": true() })
};
