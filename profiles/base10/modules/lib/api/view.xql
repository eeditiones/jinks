xquery version "3.1";

module namespace vapi="http://teipublisher.com/api/view";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../lib/util.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace custom="http://teipublisher.com/api/custom" at "../../custom-api.xql";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";

(:
: We have to provide a lookup function to templates:apply to help it
: find functions in the imported application modules. The templates
: module cannot see the application modules, but the inline function
: below does see them.
:)
declare function vapi:lookup($name as xs:string, $arity as xs:int) {
    try {
        let $cfun := custom:lookup($name, $arity)
        return
            if (empty($cfun)) then
                function-lookup(xs:QName($name), $arity)
            else
                $cfun
    } catch * {
        ()
    }
};

declare function vapi:get-template($config as map(*), $template as xs:string?) {
    if ($template) then
        $template
    else
        $config?template
};

declare function vapi:get-config($doc as xs:string, $view as xs:string?) {
    let $document := config:get-document($doc)
    return
        if (exists($document)) then
            tpu:parse-pi(root($document), $view)
        else
            error($errors:NOT_FOUND, "document " || $doc || " not found")
};

declare function vapi:load-config-json($request as map(*)?) {
    let $context := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
    return
        map:merge((
            $context,
            map {
                "languages": json-doc($config:app-root || "/resources/i18n/languages.json"),
                "request": $request,
                "context-path": $config:context-path
            }
        ))
};

(:~
: Merge the JSON config with the document/collection config
:)
declare %private function vapi:merge-config($jsonConfig as map(*), $docConfig as map(*)) {
    let $cleanedConfig := map:merge((
        (: Only keep keys that are not relevant for ODD processing :)
        for $key in map:keys($docConfig)[not(. = ('odd', 'fill', 'depth', 'media', 'view', 'template', 'output', 'type'))]
        return
            map:entry($key, $docConfig($key))
    ))
    return
        tmpl:merge-deep(($jsonConfig, $cleanedConfig))
};

declare function vapi:view($request as map(*)) {
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
            let $jsonConfig := vapi:load-config-json($request)
            let $mergedConfig := vapi:merge-config($jsonConfig, $config)
            let $model := map:merge((
                $mergedConfig,
                map {
                    "doc": map {
                        "content": $data,
                        "path": $path,
                        "odd": replace($config?odd, '^(.*)\.odd', '$1'),
                        "view": $config?view,
                        "transform": vapi:transform-helper(?, ?, $config?odd),
                        "transform-with": vapi:transform-helper#3
                    },
                    "template": $templateName,
                    "media": if (map:contains($config, 'media')) then $config?media else ()
                }
            ))
            return
                tmpl:process(serialize($template), $model, map {
                    "plainText": false(),
                    "resolver": vapi:resolver#1,
                    "modules": map {
                        "http://www.tei-c.org/tei-simple/config": map {
                            "prefix": "config",
                            "at": "modules/config.xqm"
                        }
                    },
                    "namespaces": map {
                        "tei": "http://www.tei-c.org/ns/1.0"
                    }
                })
};

declare function vapi:transform-helper($content as node()*, $parameters as map(*)?, $odd as xs:string?) {
    let $params := map:merge((
        if (map:contains($parameters, "root")) then
            $parameters
        else
            map:put($parameters, "root", $content),
        map { 
            "webcomponents": 7,
            "context-path": $config:context-path
        }
    ))
    return
        $pm-config:web-transform($content, $params, $odd)
};

declare function vapi:handle-error($error) {
    let $path := $config:app-root || "/templates/error-page.html"
    let $template :=
        if (doc-available($path)) then
            doc($path) => serialize()
        else if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    let $model := map:merge((
        vapi:load-config-json($error),
        map {
            "type": $error?code,
            "description": $error?description,
            "context-path": $config:context-path
        },
        if ($error?value?code) then
            map {
                "code": $error?value?code,
                "line": $error?value?line
            }
        else
            ()
    ))
    let $html :=
        tmpl:process($template, $model, map {
            "plainText": false(),
            "resolver": vapi:resolver#1,
            "modules": map {
                "http://www.tei-c.org/tei-simple/config": map {
                    "prefix": "config",
                    "at": "modules/config.xqm"
                }
            },
            "ignoreImports": true(),
            "ignoreUse": true()
        })
    return
        roaster:response(200, "text/html", $html)
};

declare function vapi:resolver($relPath as xs:string) as map(*)? {
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

declare function vapi:html($request as map(*)) {
    vapi:html($request, ())
};

declare function vapi:html($request as map(*), $extConfig as map(*)?) {
    let $path := $config:app-root || "/templates/" || xmldb:decode($request?parameters?file) || ".html"
    let $template :=
        if (doc-available($path)) then
            doc($path) => serialize()
        else if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else
            error($errors:NOT_FOUND, "HTML file " || $path || " not found")
    let $config := map:merge((
        vapi:load-config-json($request),
        map {
            "context-path": $config:context-path
        },
        $extConfig
    ))
    return
        tmpl:process($template, $config, map {
            "plainText": false(),
            "resolver": vapi:resolver#1,
            "modules": map {
                "http://www.tei-c.org/tei-simple/config": map {
                    "prefix": "config",
                    "at": "modules/config.xqm"
                }
            },
            "namespaces": map {
                "tei": "http://www.tei-c.org/ns/1.0"
            }
        })
};

declare function vapi:text($request as map(*)) {
    let $path := $config:app-root || "/" || xmldb:decode($request?parameters?file) || $request?parameters?suffix
    let $_ := util:log("INFO", "path: " || $path)
    let $template :=
        if (doc-available($path)) then
            doc($path) => serialize()
        else if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else
            error($errors:NOT_FOUND, "File " || $path || " not found")
     let $config := map:merge((
        vapi:load-config-json($request),
        map {
            "context-path": $config:context-path
        }
    ))
    return
        tmpl:process($template, $config, map {
            "plainText": false(),
            "resolver": vapi:resolver#1,
            "modules": map {
                "http://www.tei-c.org/tei-simple/config": map {
                    "prefix": "config",
                    "at": "modules/config.xqm"
                }
            }
        })
};
