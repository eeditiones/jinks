xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace expath="http://expath.org/ns/pkg";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace generator="http://tei-publisher.com/library/generator" at "generator.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare option output:method "html5";
declare option output:media-type "text/html";
declare option output:indent "no";

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

declare function api:generator($request as map(*)) {
    let $config := if ($request?body instance of array(*)) then $request?body?1 else $request?body
    let $overwrite := $request?parameters?overwrite
    let $dryRun := $request?parameters?dry
    let $lastModified := api:resolve-conflicts($config?config?id, $config?resolve?*)
    return
        generator:process(map { "overwrite": $overwrite, "dry": $dryRun, "last-modified": $lastModified }, $config?config)
};

declare function api:expand-template($request as map(*)) {
    let $template := $request?body?template
    let $params := head(($request?body?params, map {}))
    return
        try {
            tmpl:process($template, $params, map {
                "plainText": not($request?body?mode = ('html', 'xml')), 
                "resolver": api:resolver#1, 
                "debug": true(),
                "modules": map {
                    "https://tei-publisher.com/generator/xquery/config": map {
                        "prefix": "config",
                        "at": "modules/config.xql"
                    }
                }
            })
        } catch * {
            if (exists($err:value)) then
                roaster:response(500, "application/json", $err:value)
            else
                roaster:response(500, "application/json", $err:description)
        }
};

declare function api:configurations($request as map(*)) {
    let $installed :=
        for $collection in xmldb:get-child-collections(repo:get-root())
        let $configPath := repo:get-root() || "/" || $collection || "/config.json"
        return
            if (util:binary-doc-available($configPath)) then
                let $config := json-doc($configPath)
                return
                    if (map:contains($config, "type")) then
                        map {
                            "type": "profile",
                            "profile": $collection,
                            "title": head(($config?label, $config?pkg?title)),
                            "description": $config?description,
                            "config": $config
                        }
                    else
                        let $extConfig := generator:extends($config)
                        return
                            map {
                                "type": "installed",
                                "profile": $config?profiles?*[last()],
                                "title": head(($config?label, $config?pkg?title)),
                                "description": $config?description,
                                "config": $config,
                                "actions": $extConfig?actions
                            }
            else
                ()
    let $profiles :=
        for $collection in xmldb:get-child-collections($config:app-root || "/profiles")
        let $config := generator:profile($collection)
        return
            map {
                "type": "profile",
                "profile": $collection,
                "title": head(($config?label, $config?pkg?title)),
                "description": $config?description,
                "config": $config
            }
    return
        array { $installed, $profiles }
};

declare function api:expand-config($request as map(*)) {
    let $userConfig := $request?body
    return
        generator:extends($userConfig)
};

declare function api:profiles() {
    for $collection in xmldb:get-child-collections($config:app-root || "/profiles")
    let $config := generator:load-json($config:app-root || "/profiles/" || $collection || "/config.json", map {})
    order by if (map:contains($config, "order")) then number($config?order) else 100
    return
        map:merge((
            $config,
            map { "path": $collection }
        )),
    for $collection in xmldb:get-child-collections(repo:get-root())
    let $config := generator:load-json(repo:get-root() || "/" || $collection || "/config.json", map {})
    where map:contains($config, "type")
    return
        map:merge((
            $config,
            map { "path": $collection }
        ))
};

declare function api:page($request as map(*)) {
    let $path := $config:app-root || "/pages/" || $request?parameters?page
    let $doc := api:resolver("pages/" || $request?parameters?page)?content
    return
        if (exists($doc)) then
            let $context := map {
                "title": "jinks",
                "profiles": api:profiles(),
                "context-path": $config:context-path
            }
            let $output := tmpl:process($doc, $context, map {
                "plainText": false(), 
                "resolver": api:resolver#1,
                "modules": map {
                    "https://tei-publisher.com/generator/xquery/config": map {
                        "prefix": "config",
                        "at": "modules/config.xql"
                    }
                }
            })
            let $mime := head((xmldb:get-mime-type(xs:anyURI($path)), "text/html"))
            return
                roaster:response(200, $mime, $output)
    else
        error($errors:NOT_FOUND, $path || " not found")
};

declare function api:profile-documentation($request as map(*)) {
    let $collection := "profiles/" || $request?parameters?profile
    let $config := generator:load-json($config:app-root || "/" ||$collection || "/config.json", map {})
    let $template := api:resolver("pages/profile-documentation.html")?content
    let $context := map:merge(($config, map {
        "path": $collection,
        "name": $request?parameters?profile,
        "title": $config?label,
        "profile": $config,
        "context-path": $config:context-path,
        "base": $collection || "/doc/",
        "templating": map {
            "modules": map {
                "http://e-editiones.org/jinks/templates/util": map {
                    "prefix": "tu",
                    "at": "modules/template-utils.xql"
                }
            }
        }
    }))
    return
        tmpl:process($template, $context, map {
            "plainText": false(),
            "resolver": api:resolver#1,
            "modules": map {
                "https://tei-publisher.com/generator/xquery/config": map {
                    "prefix": "config",
                    "at": "modules/config.xql"
                }
            },
            "ignoreUse": true()
        })
};

declare function api:doc($request as map(*)) {
    let $path := $request?parameters?file || ".md"
    let $doc := api:resolver($path)?content
    return
        if (exists($doc)) then
            let $context := map {
                "title": "jinks",
                "templating": map {
                    "extends": "pages/documentation.html"
                }
            }
            let $output := tmpl:process($doc, $context, map {
                "plainText": false(),
                "resolver": api:resolver#1,
                "modules": map {
                    "https://tei-publisher.com/generator/xquery/config": map {
                        "prefix": "config",
                        "at": "modules/config.xql"
                    }
                }
            })
            return
                roaster:response(200, "text/html", $output)
    else
        error($errors:NOT_FOUND, $path || " not found")
};

declare function api:source($request as map(*)) {
    let $path := xmldb:decode($request?parameters?path)
    return
        if ($path) then
            let $filename := replace($path, "^.*/([^/]+)$", "$1")
            let $mime := xmldb:get-mime-type($path)[1]
            return
                if (util:binary-doc-available($path)) then
                    response:stream-binary(util:binary-doc($path), $mime, $filename)
                else if (doc-available($path)) then
                    roaster:response(200, $mime, doc($path))
                else
                    error($errors:NOT_FOUND, "File " || $path || " not found")
        else
            error($errors:BAD_REQUEST, "No path specified")
};

declare function api:resolve-conflict($request as map(*)) {
    let $id := $request?parameters?id
    let $path := xmldb:decode($request?parameters?path)
    return
        api:resolve-conflicts($id, $path)
};

declare %private function api:resolve-conflicts($appId as xs:string, $paths as xs:string*) {
    let $target := path:get-package-target($appId)
    return
        if ($target) then
            let $jsonPath := path:resolve-path($target, ".jinks.json")
            let $lastModified := xmldb:last-modified(path:parent($jsonPath), path:basename($jsonPath))
            let $json := generator:load-json($jsonPath, map {})
            let $updated :=
                fold-right($paths, $json, function($path, $input) {
                    map:remove($input, $path)
                }) => serialize(map { "method": "json", "indent": true()})
            let $_ := xmldb:store($target, ".jinks.json", $updated, "application/json")
            return
                $lastModified
        else
            ()
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