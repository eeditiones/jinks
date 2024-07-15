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
            doc($path) => serialize()
        else if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    return
        tmpl:process($template, api:load-config($request), map {
            "plainText": false(), 
            "resolver": api:resolver#1,
            "modules": map {
                "http://www.tei-c.org/tei-simple/config": map {
                    "prefix": "config",
                    "at": "modules/config.xqm"
                }
            }
        })
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
            let $model := map:merge((
                api:load-config($request),
                map {
                    "doc": map {
                        "path": $path,
                        "odd": replace($config?odd, '^(.*)\.odd', '$1'),
                        "view": $config?view
                    },
                    "template": $templateName,
                    "media": if (map:contains($config, 'media')) then $config?media else ()
                }
            ))
            return
                tmpl:process(serialize($template), $model, map {
                    "plainText": false(), 
                    "resolver": api:resolver#1,
                    "modules": map {
                        "http://www.tei-c.org/tei-simple/config": map {
                            "prefix": "config",
                            "at": "modules/config.xqm"
                        }
                    }
                })
};

declare function api:handle-error($error) {
    let $path := $config:app-root || "/templates/error-page.html"
    let $template :=
        if (doc-available($path)) then
            doc($path) => serialize()
        else if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    let $model := map:merge((
        api:load-config($error),
        map {
            "description": $error?description
        }
    ))
    return
        tmpl:process($template, $model, map {
            "plainText": false(), 
            "resolver": api:resolver#1,
            "modules": map {
                "http://www.tei-c.org/tei-simple/config": map {
                    "prefix": "config",
                    "at": "modules/config.xqm"
                }
            }
        })
};

declare function api:resolver($relPath as xs:string) as map(*)? {
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

declare %private function api:load-config($request as map(*)) {
    let $context := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/config.json")))
    return
        map:merge((
            $context,
            map {
                "languages": json-doc($config:app-root || "/resources/i18n/languages.json"),
                "request": $request
            }
        ))
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