xquery version "3.1";

module namespace meta="http://teipublisher.com/api/metadata-editor";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace router="http://e-editiones.org/roaster";
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

declare function meta:save($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $body := $request?body
    let $xml := config:get-document($doc)
    return
        if (exists($xml)) then
            let $updated := meta:update-header($xml, $body/*)
            let $stored := xmldb:store(util:collection-name($xml), util:document-name($xml), $updated, "application/xml")
            return
                router:response(200, "application/json", map {
                    "status": "ok",
                    "path": $stored
                })
        else
            error($errors:NOT_FOUND, "Document " || $doc || " not found")
};

declare %private function meta:update-header($nodes as node()*, $header as element(tei:teiHeader)) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document {
                    meta:update-header($node/node(), $header)
                }
            case element(tei:teiHeader) return
                $header
            case element(*) return
                element { node-name($node) } {
                    $node/@*,
                    meta:update-header($node/node(), $header)
                }
            default return
                $node
};