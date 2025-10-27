xquery version "3.1";

module namespace meta="http://teipublisher.com/api/metadata-editor";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace errors="http://e-editiones.org/roaster/errors";

declare function meta:load($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $xml := config:get-document($doc)
    return
        if (exists($xml)) then
            $xml//tei:teiHeader
        else
            error($errors:NOT_FOUND, "Document " || $doc || " not found")
};