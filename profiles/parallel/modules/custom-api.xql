xquery version "3.1";

(:~
 : This is the place to import your own XQuery modules for either:
 :
 : 1. custom API request handling functions
 : 2. custom templating functions to be called from one of the HTML templates
 :)
module namespace api="http://teipublisher.com/api/custom";

(: Add your own module imports here :)
import module namespace app="teipublisher.com/app" at "app.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace vapi="http://teipublisher.com/api/view" at "lib/api/view.xql";

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
            "context": map {
                "db-root": $config:app-root,
                "path": $config:context-path,
                "output": $config:output,
                "output-root": $config:output-root,
                "odd-root": $config:odd-root
            }
        }
    ))
    return
        tmpl:process(serialize($template), $model, false(), api:resolver#1)
};

declare function api:view($request as map(*)) {
    let $path :=
        if ($request?parameters?suffix) then 
            xmldb:decode($request?parameters?docid) || $request?parameters?suffix
        else
            xmldb:decode($request?parameters?docid)
    let $config := vapi:get-config($path, $request?parameters?view)
    let $templateName := head((vapi:get-template($config, $request?parameters?template), $config:default-template))
    let $templatePaths := ($config:app-root || "/templates/pages/" || $templateName, $config:app-root || "/templates/" || $templateName)
    let $template :=
        for-each($templatePaths, function($path) {
            if (doc-available($path)) then
                doc($path)
            else
                ()
        }) => head()
    return
        if (not($template)) then
            error($errors:NOT_FOUND, "template " || $templateName || " not found")
        else
            let $data := config:get-document($path)
            let $config := tpu:parse-pi(root($data), $request?parameters?view, $request?parameters?odd)
            let $context := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/config.json")))
            let $model := map:merge((
                $context,
                map {
                    "doc": map {
                        "path": $path,
                        "odd": replace($config?odd, '^(.*)\.odd', '$1'),
                        "view": $config?view
                    },
                    "template": $templateName,
                    "media": if (map:contains($config, 'media')) then $config?media else (),
                    "context": map {
                        "db-root": $config:app-root,
                        "path": $config:context-path,
                        "output": $config:output,
                        "output-root": $config:output-root,
                        "odd-root": $config:odd-root
                    }
                }
            ))
            return
                tmpl:process(serialize($template), $model, false(), api:resolver#1)
};

declare function api:contents($request as map(*)) {
    let $contents := id("main-contents", doc($config:data-root || "/" || $request?parameters?docid))
    let $config := tpu:parse-pi(root($contents), ())
    return
        $pm-config:web-transform($contents, map { "mode": "toc", "root": $contents, "webcomponents": 7 }, $config?odd)
};

declare function api:resolver($relPath as xs:string) {
    let $path := $config:app-root || "/" || $relPath
    return
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            ()
};

(:~
 : Keep this. This function does the actual lookup in the imported modules.
 :)
declare function api:lookup($name as xs:string, $arity as xs:integer) {
    try {
        function-lookup(xs:QName($name), $arity)
    } catch * {
        ()
    }
};