xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare option output:indent "no";

declare function api:app-root() {
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
};

declare function api:expand-template($request as map(*)) {
    let $template := $request?body?template
    let $params := head(($request?body?params, map {}))
    return
        tmpl:process($template, $params, not($request?body?mode = ('html', 'xml')), function ($relPath as xs:string) {
            let $path := api:app-root() || "/" || $relPath
            return
                if (util:binary-doc-available($path)) then
                    util:binary-doc($path) => util:binary-to-string()
                else if (doc-available($path)) then
                    doc($path) => serialize()
                else
                    ()
        }, true())
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