xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare option output:method "html5";
declare option output:media-type "text/html";
declare option output:indent "no";

declare function api:page($request as map(*)) {
    let $path := $config:app-root || "/pages/" || $request?parameters?page || ".html"
    let $doc :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            error($errors:NOT_FOUND, $path || " not found")
    let $context := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/config.json")))
    let $params := map:merge((
        map {
            "context": map {
                "db-root": $config:app-root,
                "path": $config:context-path
            }
        },
        $context
    ))
    return
        tmpl:process($doc, $params, false(), ())
};

let $lookup := function($name as xs:string) {
    try {
        function-lookup(xs:QName($name), 1)
    } catch * {
        ()
    }
}
return
    roaster:route("modules/api.json", $lookup)