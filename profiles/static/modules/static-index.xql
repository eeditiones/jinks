xquery version "3.1";

module namespace idx="http://tei-publisher.com/jinks/static/index";

import module namespace nlp="http://teipublisher.com/api/nlp" at "lib/api/nlp.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function idx:entry($request as map(*)) {
    let $path := xmldb:decode($request?parameters?id)
    let $pathPrefix := $request?parameters?prefix
    let $doc := config:get-document($path)/tei:TEI
    let $root := if (ends-with($config:data-default, "/")) then $config:data-default else $config:data-default || "/"
    return [
        map {
            "content": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'la'], true()) => string-join(),
            "translation": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'pl'], true()) => string-join(),
            "commentary": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'la']//tei:note, false()) => string-join(),
            "title": $pm-config:web-transform($doc//tei:titleStmt, map { "mode": "breadcrumb" }, $config:default-odd),
            "link": $pathPrefix || "/" || substring-after(document-uri(root($doc)), $root) || "/1/index.html",
            "places": idx:places($doc)
        }
    ]
};

declare %private function idx:get-next-page ($config, $div) {
  let $next-page := $config:next-page($config, $div, 'div')
  return if ($next-page) then ($div, idx:get-next-page($config, $next-page)) else $div
};

declare function idx:get-all-parts($config, $doc) {
  idx:get-next-page($config, $doc/descendant-or-self::tei:div[1])
};

declare function idx:entry-part($request as map(*)) {
    array {
        let $path := xmldb:decode($request?parameters?id)
        let $doc := config:get-document($path)/tei:TEI
        let $config := tpu:parse-pi(root($doc), ())
        let $pathPrefix := $request?parameters?prefix

        for $div at $i in idx:get-all-parts($config, $doc)
        return
            map {
                "content": nlp:extract-plain-text($div, true()) => string-join(),
                "title": $pm-config:web-transform($div/tei:head, map { "mode": "breadcrumb" }, $config:default-odd),
                "link": $pathPrefix || "/" || config:get-relpath($doc) || "/" || $i || "/index.html"
            }
    }
};

declare function idx:places($doc as element(tei:TEI)) {
    array {
        for $placeName in $doc//tei:text//tei:placeName
        group by $id := $placeName/@key/string()
        let $place := collection($config:register-root)/id($id)
        return
            map {
                "id": $id,
                "place": $place/tei:placeName[@type = "main"]/string()
            }
    }
};