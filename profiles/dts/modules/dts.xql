xquery version "3.1";

module namespace dts="http://teipublisher.com/api/dts";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace dts-config="http://teipublisher.com/api/dts/config" at "dts-config.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace router="http://e-editiones.org/roaster";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare %private function dts:base-path() {
    let $appLink := substring-after($config:app-root, repo:get-root())
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "api", "dts"), "/")
    return
        replace($path, "/+", "/")
};

(:~ Base path for a given collection (app) - used when listing DTS servers. :)
declare %private function dts:base-path-for-collection($collection as xs:string) {
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $collection, "api", "dts"), "/")
    return replace($path, "/+", "/")
};

(:~ Load JSON from the repo; returns empty map if not available. :)
declare %private function dts:load-json($path as xs:string) as map(*) {
    if (util:binary-doc-available($path)) then json-doc($path) else map { }
};

(:~
 : List DTS-enabled servers (applications that extend the DTS profile).
 : @return array of map { entry, title, description }
 :)
declare function dts:servers($request as map(*)) as array(*) {
    array {
        for $collection in xmldb:get-child-collections(repo:get-root())
        let $config := dts:load-json(repo:get-root() || "/" || $collection || "/config.json")
        where (array:flatten(array { $config?extends }) = "dts")
        return
            map {
                "entry": dts:base-path-for-collection($collection),
                "title": $config?label,
                "description": $config?description
            }
    }
};

(:~ 
 : DTS Entry Endpoint
 : @see https://dtsapi.org/specifications/versions/v1.0/#entry-endpoint
 : @param request The request map
 : @return the base path for the 3 endpoints: collection, navigation and document
 :)
declare function dts:entry($request as map(*)) {
    let $base := dts:base-path()
    return
        map {
            "@context": "https://dtsapi.org/context/v1.0.json",
            "@type": "EntryPoint",
            "@id": $base,
            "dtsVersion": "1.0",
            "collection": $base || "/collection/{?id,page,nav}",
            "navigation": $base || "/navigation/{?resource,ref,start,end,down,tree,page}",
            "document": $base || "/document/{?resource,ref,start,end,tree,mediaType}"
        }
};

(:~ 
 : DTS Collection Endpoint
 : @see https://dtsapi.org/specifications/versions/v1.0/#collection-endpoint
 : @param request The request map
 : @return the collection information for the given id
 :)
declare function dts:collection($request as map(*)) {
    let $collectionInfo :=
        if ($request?parameters?id) then
            dts:collection-by-id($dts-config:members, $request?parameters?id, (), $request?parameters?nav = "parents")
        else
            $dts-config:members
    return
        if (exists($collectionInfo)) then
            let $pageSize := xs:int(($request?parameters?per-page, $dts-config:page-size)[1])
            let $resources := dts:get-members($collectionInfo, $request?parameters?page, $pageSize)
            let $parentInfo := 
                if ($request?parameters?id) then
                    dts:collection-by-id($dts-config:members, $request?parameters?id, (), true())
                else
                    ()
            return map:merge((
                map {
                    "@context": "https://dtsapi.org/context/v1.0.json",
                    "@id": $collectionInfo?id,
                    "dtsVersion": "1.0",
                    "@type": "Collection",
                    "title": $collectionInfo?title,
                    "totalChildren": $resources?total,
                    "totalParents": count($parentInfo),
                    "dublinCore": $collectionInfo?dublinCore,
                    "collection": dts:base-path() || "/collection?id=" || $collectionInfo?id || "{&amp;page,nav}",
                    "member": array { $resources?items }
                },
                dts:pagination-info($collectionInfo, $request?parameters?page, $resources?total)
            ))
        else
            response:set-status-code(404)
};

declare %private function dts:pagination-info($collectionInfo as map(*), $page as xs:int, $count as xs:int) {
    if ($count > $dts-config:page-size) then
        map {
            "view":
                map:merge((
                    map {
                        "@type": "Pagination",
                        "@id": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || $page,
                        "first": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=1",
                        "last": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ceiling($count div $dts-config:page-size)
                    },
                    if ($page > 1) then
                        map:entry("previous", dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ($page - 1))
                    else (),
                    if ($page < ceiling($count div $dts-config:page-size)) then
                        map:entry("next", dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ($page + 1))
                    else ()
                ))
        }
    else ()
};

declare %private function dts:collection-by-id($collectionInfo as map(*), $id as xs:string, $parentInfo as map(*)?, 
    $returnParent as xs:boolean?) {
    if ($collectionInfo?id = $id) then
        if ($returnParent) then $parentInfo else $collectionInfo
    else
        for $member in $collectionInfo?members?*
        return
            dts:collection-by-id($member, $id, $collectionInfo, $returnParent)
};

declare %private function dts:get-members($collectionInfo as map(*), $page as xs:int, $pageSize as xs:int) {
    if (map:contains($collectionInfo, "members")) then
        map {
            "total": count($collectionInfo?members?*),
            "items": 
                for $resource in $collectionInfo?members?*
                    return
                        map {
                        "@id": $resource?id,
                        "title": $resource?title,
                        "dublinCore": $resource?dublinCore,
                        "@type": "Collection",
                        "totalParents": 1,
                        "totalChildren": count($resource?members?*),
                        "collection": dts:base-path() || "/collection?id=" || $resource?id || "{&amp;page,nav}"
                    }
        }
    else
        let $collectionPath :=
            if (map:contains($collectionInfo, "path")) then $collectionInfo?path else $config:data-default
        let $resources :=
            collection($collectionPath)//tei:text[ft:query(., "file:*", $query:QUERY_OPTIONS)]
        return
            map {
                "total": count($resources),
                "items": 
                    for $resource in subsequence($resources, ($page - 1) * $pageSize + 1, $pageSize)
                    let $id := util:document-name($resource)
                    let $config := tpu:parse-pi(root($resource), ())
                    return
                        map:merge((
                            map {
                                "@id": $collectionInfo?id || "/" || $id,
                                "title": $id,
                                "@type": "Resource",
                                "totalParents": 1,
                                "totalChildren": 0,
                                "collection": dts:base-path() || "/collection?id=" || encode-for-uri($collectionInfo?id) || "{&amp;page,nav}",
                                "document": dts:base-path() || "/document?resource=" || encode-for-uri($collectionInfo?id || "/" || $id) || "{&amp;ref,start,end,tree,mediaType}",
                                "navigation": dts:base-path() || "/navigation?resource=" || encode-for-uri($collectionInfo?id || "/" || $id) || "{&amp;down}",
                                "mediaTypes": array {
                                    "application/tei+xml",
                                    "application/xml",
                                    for $media in $config?media
                                    return
                                        switch ($media)
                                            case "latex" return "application/pdf; media=latex"
                                            case "fo" return "application/pdf; media=fo"
                                            case "epub" return "application/epub+zip; media=epub"
                                            case "markdown" return "text/markdown"
                                            case "print" return "text/html; charset=utf-8; media=print"
                                            default return "text/html; charset=utf-8"
                                }
                            },
                            dts:metadata($resource)
                        ))
            }
};

(:~ 
 : DTS Document Endpoint
 : @see https://dtsapi.org/specifications/versions/v1.0/#document-endpoint
 : @param request The request map
 : @return the document content for the given resource
 :)
declare function dts:document($request as map(*)) {
    let $resource := $request?parameters?resource
    return
        if (empty($resource) or $resource = "") then
            response:set-status-code(400)
        else if (($request?parameters?ref and ($request?parameters?start or $request?parameters?end)) or
                (exists($request?parameters?start) and empty($request?parameters?end)) or
                (exists($request?parameters?end) and empty($request?parameters?start))) then
            response:set-status-code(400)
        else
            let $collection := dts:collection-by-id($dts-config:members, substring-before($resource, "/"), (), false())
            let $doc := doc($collection?path || "/" || substring-after($resource, "/"))
            let $mediaType := $request?parameters?mediaType
            let $parsedMediaType := tokenize(($mediaType, "application/xml")[1], ";")
            return
                if (empty($collection) or empty($doc)) then
                    router:response(404, "text/plain", "Resource not found")
                else
                    let $xml := dts:resolve-fragment($doc, $request?parameters?ref, $request?parameters?start, $request?parameters?end)
                    return
                        if (empty($xml)) then
                            router:response(404, "text/plain", "Fragment not found")
                        else
                            let $collection-link := "<" || dts:base-path() || "/collection?id=" || encode-for-uri(substring-before($resource, "/")) || ">; rel=""collection"""
                            let $doc-filename := (tokenize($resource, "/")[last()], "document.xml")[1]
                            let $disposition-filename := if (matches($doc-filename, "\.(xml|tei)$", "i")) then $doc-filename else $doc-filename || ".xml"
                            return
                                (response:set-header("Link", $collection-link),
                                response:set-header("Content-Disposition", "inline; filename=""" || $disposition-filename || """"),
                                if ($xml instance of document-node()) then
                                    let $config := tpu:parse-pi($xml, ())
                                    let $output :=
                                        switch ($parsedMediaType[1])
                                            case "text/html" return
                                                if ($parsedMediaType[3] = "media=print") then
                                                    $pm-config:print-transform($xml, map { "root": root($xml) }, $config?odd)
                                                else
                                                    $pm-config:web-transform($xml, map { "root": root($xml) }, $config?odd)
                                            case "application/epub+zip" return $pm-config:epub-transform($xml, map { "root": root($xml) }, $config?odd)
                                            default return dts:check-pi(root($xml))
                                    let $content-type := if ($parsedMediaType[1] = "application/xml" or $parsedMediaType[1] = "") then "application/tei+xml" else $parsedMediaType[1]
                                    return router:response(200, $content-type, $output)
                                else if ($xml instance of element()) then
                                    let $output :=
                                        switch ($parsedMediaType[1])
                                            case "text/html" return
                                                 let $config := tpu:parse-pi(root($xml), ())
                                                 return
                                                    $pm-config:web-transform($xml, map { "root": root($xml) }, $config?odd)
                                            default return
                                                document {
                                                    <TEI xmlns="http://www.tei-c.org/ns/1.0">
                                                        <dts:wrapper xmlns:dts="https://w3id.org/api/dts#">
                                                            {$xml}
                                                        </dts:wrapper>
                                                    </TEI>
                                                }
                                    let $content-type := if ($parsedMediaType[1] = "text/html") then "text/html" else "application/tei+xml"
                                    return router:response(200, $content-type, $output)
                                else
                                    router:response(404, "text/plain", "Fragment not found"))
};

(:~ 
 : DTS Navigation Endpoint
 : @see https://dtsapi.org/specifications/versions/v1.0/#navigation-endpoint
 : @param request The request map
 : @return the navigation information for the given resource
 :)
declare function dts:navigation($request as map(*)) {
    let $resource := $request?parameters?resource
    return
        if (empty($resource) or $resource = "") then
            response:set-status-code(400)
        else if (($request?parameters?ref and ($request?parameters?start or $request?parameters?end)) or
                ($request?parameters?start and empty($request?parameters?end)) or
                ($request?parameters?end and empty($request?parameters?start))) then
            response:set-status-code(400)
        else
            let $collection := dts:collection-by-id($dts-config:members, substring-before($resource, "/"), (), false())
            let $doc :=
                doc($collection?path || "/" || substring-after($resource, "/"))//tei:text[ft:query(., "file:*", $query:QUERY_OPTIONS)]
            return
                if (empty($collection) or empty($doc)) then
                    response:set-status-code(404)
                else
                    let $config := tpu:parse-pi(root($doc), ())
                    let $down-param := $request?parameters?down
                    let $down := if (exists($down-param)) then xs:int($down-param) else 0
                    let $ref := $request?parameters?ref
                    let $ref-unit := if (exists($ref)) then dts:ref-citable-unit($doc, $ref, $config?odd) else ()
                    return
                        if (exists($ref) and empty($ref-unit)) then
                            response:set-status-code(404)
                        else
                            let $member :=
                                if (exists($ref)) then
                                    dts:navigation-by-ref($doc, $config?odd, $ref, $down-param, $down)
                                else
                                    dts:navigation-tree($doc//tei:body/tei:div, $config?odd, $down, 0)
                            let $resourceId := $collection?id || "/" || util:document-name($doc)
                            return
                                map:merge((
                                    map {
                                        "@context": "https://dtsapi.org/context/v1.0.json",
                                        "dtsVersion": "1.0",
                                        "@type": "Navigation",
                                        "@id": dts:base-path() || "/navigation?resource=" || encode-for-uri($resource) || (if (exists($down-param)) then "&amp;down=" || $down else ""),
                                        "resource":
                                            map:merge((
                                                map {
                                                    "@id": $resourceId,
                                                    "title": util:document-name($doc),
                                                    "@type": "Resource",
                                                    "totalParents": 1,
                                                    "totalChildren": 0,
                                                    "collection": dts:base-path() || "/collection?id=" || encode-for-uri($collection?id) || "{&amp;page,nav}",
                                                    "navigation": dts:base-path() || "/navigation?resource=" || encode-for-uri($resourceId) || "{&amp;ref,start,end,down,tree,page}",
                                                    "document": dts:base-path() || "/document?resource=" || encode-for-uri($resourceId) || "{&amp;ref,start,end,tree,mediaType}",
                                                    "citationTrees": array {
                                                        map {
                                                            "@type": "CitationTree",
                                                            "citeStructure": array {
                                                                dts:cite-structure($doc//tei:body)
                                                            }
                                                        }
                                                    }
                                                },
                                                dts:metadata($doc)
                                            )),
                                        "member": $member
                                    },
                                    (if (exists($ref)) then map { "ref": $ref-unit } else map {})
                                ))
};

(:~ When ref is present and down is not provided, return empty array; else siblings (down=0) or subtree (down>0 or -1). :)
declare %private function dts:navigation-by-ref($doc as document-node(), $odd as xs:string, $ref as xs:string, $down-param as xs:anyAtomicType?, $down as xs:int) as array(*) {
    let $node := dts:resolve-ref-node($doc, $ref)
    return
        if (empty($node)) then array { }
        else if (empty($down-param)) then array { }
        else if ($down = 0) then
            array {
                for $sibling in $node/parent::tei:div/tei:div
                return map {
                    "@type": "CitableUnit",
                    "citeType": "Division",
                    "level": count($sibling/ancestor::tei:div) + 1,
                    "dublinCore": map { "title": dts:heading(head(($sibling/tei:head, $sibling/@n)), $odd) },
                    "parent": dts:get-identifier($sibling/parent::tei:div),
                    "identifier": dts:get-identifier($sibling)
                }
            }
        else
            array {
                dts:ref-citable-unit($doc, $ref, $odd),
                dts:navigation-tree($node/tei:div, $odd, $down, 1)
            }
};

declare %private function dts:ref-citable-unit($doc as document-node(), $ref as xs:string, $odd as xs:string) as map(*)? {
    let $node := dts:resolve-ref-node($doc, $ref)
    return
        if (empty($node)) then ()
        else
            map {
                "identifier": dts:get-identifier($node),
                "@type": "CitableUnit",
                "level": count($node/ancestor::tei:div) + 1,
                "parent": dts:get-identifier($node/parent::tei:div),
                "citeType": "Division",
                "dublinCore": map { "title": dts:heading(head(($node/tei:head, $node/@n)), $odd) }
            }
};

declare %private function dts:resolve-ref-node($doc as document-node(), $ref as xs:string) as element()? {
    let $by-id := $doc/id($ref)
    return
        if ($by-id instance of element()) then $by-id
        else
            let $by-node-id := util:node-by-id($doc, substring-after($ref, "exist:"))
            return
                if ($by-node-id instance of element()) then $by-node-id
                else ()
};

declare %private function dts:metadata($doc as element()) {
    map {
        "title": ft:field($doc, "title"),
        "dublinCore":
            map {
                "creator": ft:field($doc, "author"),
                "date": ft:field($doc, "date"),
                "language": ft:field($doc, "language")
            }
    }
};

declare %private function dts:check-pi($doc as document-node()) {
    let $pi := $doc/processing-instruction("teipublisher")
    return
        if ($pi) then
            $doc
        else
            let $config := config:default-config(document-uri($doc))
            return
                document {
                    processing-instruction teipublisher {
                        ``[odd="`{$config?odd}`" view="`{$config?view}`" template="`{$config?template}`"]``
                    },
                    $doc/node()
                }
};

declare %private function dts:store-temp($data as node()*, $name as xs:string) {
    let $tempCol :=
        if (xmldb:collection-available($config:data-root || "/dts")) then
            $config:data-root || "/dts"
        else
            xmldb:create-collection($config:data-root, "dts")
    return
        xmldb:store($tempCol, $name, $data, "application/xml")
};

declare %private function dts:store($data as node()*, $name as xs:string) {
    xmldb:store($dts-config:import-collection, $name, $data, "application/xml")
};

declare %private function dts:clear-temp() {
    let $docs := collection($config:data-root || "/dts")
    let $until := current-dateTime() - xs:dayTimeDuration("P1D")
    for $outdated in xmldb:find-last-modified-until($docs, $until)
    return
        xmldb:remove(util:collection-name($outdated), util:document-name($outdated))
};

declare function dts:import($request as map(*)) {
    dts:clear-temp(),
    let $options := <http:request method="GET" href="{$request?parameters?uri}"/>
    let $response := http:send-request($options)
    return
        if ($response[1]/@status = "200") then (
            let $stored :=
                if ($request?parameters?temp) then
                    dts:store-temp(tail($response), util:hash($request?parameters?uri, "md5") || ".xml")
                else
                    dts:store(tail($response), util:hash($request?parameters?uri, "md5") || ".xml")
            return
                router:response(201, "application/json",
                    map {
                        "path": substring-after($stored, $config:data-root || "/")
                    }
                )
        )
        else
            response:set-status-code($response[1]/@status)
};

declare %private function dts:cite-structure($roots as element()*) {
    for $root in $roots
    return
        map {
            "@type": "CiteStructure",
            "citeType": "Division",
            "citeStructure": [
                dts:cite-structure($root/tei:div)
            ]
        }
};

declare %private function dts:navigation-tree($roots as element()*, $odd as xs:string, $down as xs:int, $level as xs:int) {
    for $root in $roots
    return (
        map {
            "@type": "CitableUnit",
            "citeType": "Division",
            "level": count($root/ancestor::tei:div) + 1,
            "dublinCore": map {
                "title": dts:heading(head(($root/tei:head, $root/@n)), $odd)
            },
            "parent": dts:get-identifier($root/parent::tei:div),
            "identifier": dts:get-identifier($root)
        },
        if ($down < 0 or $level < $down) then
            dts:navigation-tree($root/tei:div, $odd, $down, $level + 1)
        else
            ()
    )
};

declare %private function dts:heading($root as item()?, $odd as xs:string) {
    if (empty($root)) then
        ()
    else 
        typeswitch ($root)
            case attribute() | text() | xs:string return
                $root/string()
            default return
                $pm-config:web-transform($root, map { "root": $root, "mode": "toc" }, $odd)
};

declare %private function dts:get-identifier($node as node()?) {
    if (empty($node)) then
        ()
    else
        head(($node/@xml:id/string(), "exist:" || util:node-id($node)))
};

declare %private function dts:resolve-fragment($doc as document-node(), $ref as xs:string?, $start as xs:string?, $end as xs:string?) as node()? {
    if (exists($start) and exists($end)) then
        let $start-node := dts:resolve-ref-node($doc, $start)
        let $end-node := dts:resolve-ref-node($doc, $end)
        return
            if (empty($start-node) or empty($end-node)) then ()
            else $start-node
    else if (empty($ref)) then
        $doc
    else
        let $xml := $doc/id($ref)
        return
            if ($xml) then
                $xml
            else
                util:node-by-id($doc, substring-after($ref, "exist:"))
};