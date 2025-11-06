xquery version "3.1";

module namespace ridx="http://tei-publisher.com/jinks/serafin/index";

import module namespace nlp="http://teipublisher.com/api/nlp" at "lib/api/nlp.xqm";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~
 : Overwrite the indexes for a single document entry.
 :
 : @param $request The request map
 : @return The index entry
 :)
declare function ridx:entry($request as map(*)) {
    let $path := xmldb:decode($request?parameters?id)
    let $pathPrefix := $request?parameters?prefix
    let $doc := config:get-document($path)/tei:TEI
    let $root := if (ends-with($config:data-default, "/")) then $config:data-default else $config:data-default || "/"
    return [
        map {
            "content": nlp:extract-plain-text($doc//tei:text[@type = 'source'], true()) => string-join(),
            "translation": nlp:extract-plain-text($doc//tei:text[@type = 'translation'], true()) => string-join(),
            "commentary": nlp:extract-plain-text($doc//tei:text[@type = 'source']//tei:note, false()) => string-join(),
            "title": nlp:extract-plain-text($doc//tei:titleStmt/tei:title[not(@level)], false()) => string-join(),
            "link": $pathPrefix || "/" || substring-after(document-uri(root($doc)), $root) || "/1/index.html",
            "places": ridx:places($doc)
        }
    ]
};

declare function ridx:places($doc as element(tei:TEI)) {
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