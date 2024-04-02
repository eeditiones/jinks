xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare option output:indent "no";

declare function api:expand-template($request as map(*)) {
    let $template := $request?body?template
    let $params := head(($request?body?params, map {}))
    return
        try {
            tmpl:process($template, $params, not($request?body?mode = ('html', 'xml')), function ($relPath as xs:string) {
                let $path := $config:app-root || "/" || $relPath
                return
                    if (util:binary-doc-available($path)) then
                        util:binary-doc($path) => util:binary-to-string()
                    else if (doc-available($path)) then
                        doc($path) => serialize()
                    else
                        ()
            }, true())
        } catch * {
            roaster:response(500, $err:description)
        }
};

declare function api:page($request as map(*)) {
    let $path := $config:app-root || "/pages/" || $request?parameters?page || ".html"
    let $doc :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            roaster:response(404, $path || " not found")
    let $params := map {
        "context": map {
            "db-root": $config:app-root,
            "path": $config:context-path
        },
        "title": "TEI Publisher Templating"
    }
    return
        tmpl:process($doc, $params, true(), ())
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