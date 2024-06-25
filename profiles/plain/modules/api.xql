xquery version "3.1";

declare namespace api="http://teipublisher.com/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare function api:html($request as map(*)) {
    let $path := $config:app-root || "/templates/" || xmldb:decode($request?parameters?file) || ".html"
    let $template :=
        if (doc-available($path)) then
            doc($path)
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    let $context := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/config.json")))
    let $model := map:merge((
        $context,
        map {
            "languages": json-doc($config:app-root || "/resources/i18n/languages.json"),
            "request": $request
        }
    ))
    return
        tmpl:process(serialize($template), $model, map {
            "plainText": false(), 
            "resolver": api:resolver#1,
            "modules": map {
                "uri": "https://tei-publisher.com/generator/xquery/config",
                "prefix": "config",
                "at": $config:app-root || "/modules/config.xql"
            }
        })
};

declare %private function api:resolver($relPath as xs:string) as map(*)? {
    let $path := $config:app-root || "/" || $relPath
    let $content :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            ()
    return
        if ($content) then
            map {
                "path": $path,
                "content": $content
            }
        else
            ()
};

declare function api:handle-error($error) {
    let $path := $config:app-root || "/templates/error-page.html"
    let $template :=
        if (doc-available($path)) then
            doc($path)
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    return
        tmpl:process(
            serialize($template), 
            map {
                "description": $error?description
            }, 
            map {
                "plainText": false(), 
                "resolver": api:resolver#1
            }
        )
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