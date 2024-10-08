xquery version "3.1";

module namespace idx="http://tei-publisher.com/jinks/static/index";

import module namespace nlp="http://teipublisher.com/api/nlp" at "lib/api/nlp.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function idx:entry($request as map(*)) {
    let $path := xmldb:decode($request?parameters?id)
    let $doc := config:get-document($path)/tei:TEI
    return
        map {
            "content": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'la'], true()) => string-join(),
            "translation": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'pl'], true()) => string-join(),
            "commentary": nlp:extract-plain-text($doc//tei:text[@xml:lang = 'la']//tei:note, false()) => string-join(),
            "title": $pm-config:web-transform($doc//tei:titleStmt, map { "mode": "breadcrumb" }, $config:default-odd),
            "link": "documents/" || config:get-relpath($doc) || "/1/index.html",
            "places": idx:places($doc)
        }
};

declare function idx:places($doc as element(tei:TEI)) {
    array {
        for $place in $doc//tei:text//tei:placeName
        group by $id := $place/@ref/string()
        return
            $id
    }
};