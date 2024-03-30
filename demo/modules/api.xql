xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare option output:indent "no";

declare variable $api:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
    (: strip the xmldb: part :)
    if (starts-with($rawPath, "xmldb:exist://")) then
        if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
            substring($rawPath, 36)
        else
            substring($rawPath, 15)
    else
        $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $api:context-path := request:get-context-path() || substring-after($api:app-root, "/db");

declare function api:expand-template($request as map(*)) {
    let $template := $request?body?template
    let $params := head(($request?body?params, map {}))
    return
        tmpl:process($template, $params, not($request?body?mode = ('html', 'xml')), function ($relPath as xs:string) {
            let $path := $api:app-root || "/" || $relPath
            return
                if (util:binary-doc-available($path)) then
                    util:binary-doc($path) => util:binary-to-string()
                else if (doc-available($path)) then
                    doc($path) => serialize()
                else
                    ()
        }, true())
};

declare function api:page($request as map(*)) {
    let $path := $api:app-root || "/pages/" || $request?parameters?page || ".html"
    let $doc :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            roaster:response(404, $path || " not found")
    let $params := map {
        "context": map {
            "db-root": $api:app-root,
            "path": $api:context-path
        },
        "title": "TEI Publisher Templating"
    }
    let $html := tmpl:process($doc, $params, true(), ())
    return
        $html?result
};

let $lookup := function($name as xs:string) {
    try {
        function-lookup(xs:QName($name), 1)
    } catch * {
        ()
    }
}
let $resp := roaster:route("modules/api.json", $lookup)
return
    $resp