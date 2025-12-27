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
    let $template := if ($request?body instance of map(*)) then $request?body?template else $request?body
    let $params := if ($request?body instance of map(*)) then head(($request?body?params, map {})) else map {}
    let $mode := if ($request?body instance of map(*)) then $request?body?mode else ()
    return
        try {
            if ($request?parameters?force-error = true()) then
                error(xs:QName('err:FORCED'), 'Forced error for testing')
            else
                tmpl:process($template, $params, map {
                "plainText": not($mode = ('html', 'xml')), 
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

declare %private function api:get-user() as xs:string {
    let $user := sm:id()/sm:id/sm:real/sm:username/string()
    return
        if ($user) then
            $user
        else
            "guest"
};

declare %private function api:sub-collections($root as xs:string, $children as xs:string*, $user as xs:string) as array(*)? {
    let $result :=
        for $child in $children
        let $processChild := api:collections(concat($root, '/', $child), $child, $user)
        where exists($processChild)
        order by $child collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
        return
            $processChild
    return
        if (exists($result)) then
            array { $result }
        else
            ()
};

declare %private function api:collections($root as xs:string, $child as xs:string, $user as xs:string) as map(*)? {
    if (sm:has-access(xs:anyURI($root), "x")) then
        let $children := xmldb:get-child-collections($root)
        let $canWrite := sm:has-access(xs:anyURI($root), "w")
        return
            if (sm:has-access(xs:anyURI($root), "r")) then
                map:merge((
                    map {
                        "title": xmldb:decode-uri(xs:anyURI($child)),
                        "isFolder": true(),
                        "key": xs:anyURI($root),
                        "writable": $canWrite,
                        "addClass": if ($canWrite) then "writable" else "readable"
                    },
                    if (exists($children)) then
                        map { "children": api:sub-collections($root, $children, $user) }
                    else
                        map {}
                ))
            else
                ()
    else
        ()
};
declare function api:list($request as map(*)) {
    let $type := $request?parameters?type
    return
        switch ($type)
            case "c" return
                api:list-collections($request)
            case "r" return
                api:list-resources($request)
            default return
                error($errors:BAD_REQUEST, "Invalid type: " || $type)
};

declare %private function api:list-collections($request as map(*)) {
    let $root := head(($request?parameters?root, "/db"))
    let $collName := replace($root, "^.*/([^/]+$)", "$1")
    let $user := api:get-user()
    return
        roaster:response(200, "application/json", array { api:collections($root, $collName, $user) })
};

declare %private function api:list-collection-contents($collection as xs:string, $user as xs:string, $filter as xs:string?) as xs:string* {
    let $subcollections :=
        for $child in xmldb:get-child-collections($collection)
        let $collpath := concat($collection, "/", $child)
        where sm:has-access(xs:anyURI($collpath), "r")
        return
            concat("/", $child)
    let $resources :=
        for $r in xmldb:get-child-resources($collection)
        where sm:has-access(xs:anyURI(concat($collection, "/", $r)), "r")
        return
            $r
    let $all := if ($filter) then ($subcollections, $resources)[contains(., $filter)] else ($subcollections, $resources)
    for $resource in $all
    order by $resource collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
    return
        $resource
};

declare %private function api:list-resources($request as map(*)) {
    let $collection := $request?parameters?collection
    let $user := api:get-user()
    let $start := (number(head(($request?parameters?start, 0))) + 1) cast as xs:integer
    let $endParam := (number(head(($request?parameters?end, 1000000))) + 1) cast as xs:integer
    let $filter := $request?parameters?filter
    let $resources := api:list-collection-contents($collection, $user, $filter)
    let $count := count($resources) + 1
    let $end := if ($endParam gt $count) then $count else $endParam
    let $subset := subsequence($resources, $start, $end - $start + 1)
    let $parent := $start = 1 and $collection != "/db"
    let $items :=
        (
            if ($parent) then
                map {
                    "name": "..",
                    "permissions": "",
                    "owner": "",
                    "group": "",
                    "last-modified": "",
                    "writable": sm:has-access(xs:anyURI($collection), "w"),
                    "isCollection": true(),
                    "key": $collection
                }
            else
                (),
            for $resource in $subset
            let $isCollection := starts-with($resource, "/")
            let $path :=
                if ($isCollection) then
                    concat($collection, $resource)
                else
                    concat($collection, "/", $resource)
            where sm:has-access(xs:anyURI($path), "r")
            order by $resource collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
            return
                let $permissions := sm:get-permissions(xs:anyURI($path))/sm:permission
                let $owner := $permissions/@owner/string()
                let $group := $permissions/@group/string()
                let $lastMod :=
                    let $date :=
                        if ($isCollection) then
                            xmldb:created($path)
                        else
                            xmldb:last-modified($collection, $resource)
                    return
                        if (xs:date($date) = current-date()) then
                            format-dateTime($date, "Today [H00]:[m00]:[s00]")
                        else
                            format-dateTime($date, "[M00]/[D00]/[Y0000] [H00]:[m00]:[s00]")
                let $canWrite := sm:has-access(xs:anyURI($path), "w")
                let $permStr := string($permissions/@mode)
                let $permDisplay := 
                    if ($isCollection) then "c" else "-" ||
                    $permStr ||
                    (if ($permissions/sm:acl/@entries ne "0") then "+" else "")
                return map:merge((
                    map {
                        "name": xmldb:decode-uri(xs:anyURI(if ($isCollection) then substring-after($resource, "/") else $resource)),
                        "permissions": $permDisplay,
                        "owner": $owner,
                        "group": $group,
                        "key": xs:anyURI($path),
                        "last-modified": $lastMod,
                        "writable": $canWrite,
                        "isCollection": $isCollection
                    },
                    if (not($isCollection)) then
                        map { "mime": xmldb:get-mime-type(xs:anyURI($path)) }
                    else
                        ()
                ))
        )
    return
        roaster:response(200, "application/json", map {
            "total": count($resources) + (if ($parent) then 1 else 0),
            "items": array { $items }
        })
};

declare function api:create-collection($request as map(*)) {
    let $body := $request?body
    let $collName := $body?name
    let $parent := head(($body?collection, "/db"))
    let $user := api:get-user()
    return
        if (sm:has-access(xs:anyURI($parent), "w")) then
            try {
                let $_ := xmldb:create-collection($parent, $collName)
                return
                    roaster:response(200, "application/json", map { "status": "ok" })
            } catch * {
                roaster:response(500, "application/json", map {
                    "status": "fail",
                    "message": $err:description
                })
            }
        else
            roaster:response(403, "application/json", map {
                "status": "fail",
                "message": "You are not allowed to write to collection " || xmldb:decode-uri(xs:anyURI($parent))
            })
};

declare %private function api:delete-collection($collName as xs:string, $user as xs:string) as map(*) {
    if (sm:has-access(xs:anyURI($collName), "w")) then
        try {
            let $_ := xmldb:remove($collName)
            return
                map { "status": "ok" }
        } catch * {
            map {
                "status": "fail",
                "item": $collName,
                "message": $err:description
            }
        }
    else
        map {
            "status": "fail",
            "item": $collName,
            "message": "You are not allowed to write to collection " || xmldb:decode-uri(xs:anyURI($collName))
        }
};

declare %private function api:delete-resource($collection as xs:string, $resource as xs:string, $user as xs:string) as map(*) {
    let $components := analyze-string($resource, "^(.*)/([^/]+)$")//fn:group/string()
    let $resource-collection := $components[1]
    let $resource-name := $components[2]
    let $canWrite :=
        sm:has-access(xs:anyURI($resource), "w") and
        sm:has-access(xs:anyURI($resource-collection), "w")
    return
        if ($canWrite) then
            try {
                let $_ := xmldb:remove($resource-collection, $resource-name)
                return
                    map { "status": "ok" }
            } catch * {
                map {
                    "status": "fail",
                    "item": $resource,
                    "message": $err:description
                }
            }
        else
            map {
                "status": "fail",
                "item": $resource,
                "message": "You are not allowed to write to resource " || $resource
            }
};

declare function api:delete-resources($request as map(*)) {
    let $collection := $request?parameters?collection
    let $removeParam := $request?parameters?remove
    let $selections :=
        if ($removeParam instance of array(*)) then
            $removeParam?*
        else if ($removeParam instance of xs:string) then
            $removeParam
        else
            $removeParam
    let $user := api:get-user()
    let $results :=
        for $selection in $selections
        let $path :=
            if (starts-with($selection, "/")) then
                $selection
            else
                $collection || "/" || $selection
        let $isCollection := xmldb:collection-available($path)
        let $response :=
            if ($isCollection) then
                api:delete-collection($path, $user)
            else
                api:delete-resource($collection, $path, $user)
        return
            $response
    return
        if (some $r in $results satisfies $r?status = "fail") then
            let $failures := $results[?status = "fail"]
            let $failedItems := string-join($failures?item, ", ")
            return
                roaster:response(500, "application/json", map {
                    "status": "fail",
                    "message": "Deletion of the following items failed: " || $failedItems || "."
                })
        else
            roaster:response(200, "application/json", map { "status": "ok" })
};

declare %private function api:copy-or-move($operation as xs:string, $sourceCollection as xs:string, $target as xs:string, $sources as xs:string+, $user as xs:string) {
    if (sm:has-access(xs:anyURI($target), "w")) then
        let $results :=
            for $source in $sources
            let $sourcePath :=
                if (starts-with($source, "/")) then
                    $source
                else
                    $sourceCollection || "/" || $source
            let $isCollection := xmldb:collection-available($sourcePath)
            return
                try {
                    if ($isCollection) then
                        let $_ :=
                            switch ($operation)
                                case "move" return
                                    xmldb:move($sourcePath, $target)
                                default return
                                    xmldb:copy-collection($sourcePath, $target)
                        return
                            map { "status": "ok" }
                    else
                        let $split := analyze-string($sourcePath, "^(.*)/([^/]+)$")//fn:group/string()
                        let $_ :=
                            switch ($operation)
                                case "move" return
                                    xmldb:move($split[1], $target, $split[2])
                                default return
                                    xmldb:copy-resource($split[1], $split[2], $target, $split[2])
                        return
                            map { "status": "ok" }
                } catch * {
                    map {
                        "status": "fail",
                        "message": $err:description,
                        "code": $err:code
                    }
                }
        return
            if (some $r in $results satisfies $r?status = "fail") then
                let $failures := $results[?status = "fail"]
                return
                    roaster:response(500, "application/json", map {
                        "status": "fail",
                        "message": "Operation failed for some items",
                        "errors": array { $failures }
                    })
            else
                roaster:response(200, "application/json", map { "status": "ok" })
    else
        roaster:response(403, "application/json", map {
            "status": "fail",
            "message": "You are not allowed to write to collection " || xmldb:decode-uri(xs:anyURI($target))
        })
};

declare function api:copy-resources($request as map(*)) {
    let $collection := $request?parameters?collection
    let $body := $request?body
    let $target := $body?target
    let $sources :=
        if ($body?sources instance of array(*)) then
            $body?sources?*
        else
            $body?sources
    let $user := api:get-user()
    return
        api:copy-or-move("copy", $collection, $target, $sources, $user)
};

declare function api:move-resources($request as map(*)) {
    let $collection := $request?parameters?collection
    let $body := $request?body
    let $target := $body?target
    let $sources :=
        if ($body?sources instance of array(*)) then
            $body?sources?*
        else
            $body?sources
    let $user := api:get-user()
    return
        api:copy-or-move("move", $collection, $target, $sources, $user)
};

declare function api:rename-resource($request as map(*)) {
    let $collection := $request?parameters?collection
    let $resource := $request?parameters?resource
    let $body := $request?body
    let $newName := $body?name
    return
        if (not($newName)) then
            roaster:response(400, "application/json", map {
                "status": "fail",
                "message": "Missing required parameter: name"
            })
        else
            try {
                let $isCollection := xmldb:collection-available($collection || "/" || $resource)
                let $_ :=
                    if ($isCollection) then
                        xmldb:rename($collection || "/" || $resource, $newName)
                    else
                        xmldb:rename($collection, $resource, $newName)
                return
                    roaster:response(200, "application/json", map { "status": "ok" })
            } catch * {
                roaster:response(500, "application/json", map {
                    "status": "fail",
                    "message": $err:description,
                    "code": $err:code
                })
            }
};

declare %private function api:merge-properties($maps as map(*)+) as map(*) {
    map:merge(
        for $key in map:keys($maps[1])
        let $values := distinct-values(for $map in $maps return $map($key))
        return
            map:entry($key, if (count($values) = 1) then $values[1] else "")
    )
};

declare %private function api:get-property-map($resource as xs:string) as map(*) {
    let $isCollection := xmldb:collection-available($resource)
    let $permissions := sm:get-permissions(xs:anyURI($resource))/sm:permission
    return
        if ($isCollection) then
            map {
                "owner": $permissions/@owner/string(),
                "group": $permissions/@group/string(),
                "last-modified": format-dateTime(xmldb:created($resource), "[MNn] [D00] [Y0000] [H00]:[m00]:[s00]"),
                "permissions": string($permissions/@mode),
                "mime": xmldb:get-mime-type(xs:anyURI($resource))
            }
        else
            let $components := analyze-string($resource, "^(.*)/([^/]+)$")//fn:group/string()
            return
                map {
                    "owner": $permissions/@owner/string(),
                    "group": $permissions/@group/string(),
                    "last-modified": format-dateTime(xmldb:last-modified($components[1], $components[2]), "[MNn] [D00] [Y0000] [H00]:[m00]:[s00]"),
                    "permissions": string($permissions/@mode),
                    "mime": xmldb:get-mime-type(xs:anyURI($resource))
                }
};

declare %private function api:merge-resource-properties($resources as xs:string*) as map(*) {
    api:merge-properties(for $resource in $resources return api:get-property-map($resource))
};

declare %private function api:checkbox($name as xs:string, $test as xs:boolean) as element() {
    <input type="checkbox" name="{$name}" id="{$name}">
    {
        if ($test) then attribute checked { 'checked' } else ()
    }
    </input>
};

declare %private function api:get-permissions($perms as xs:string) as element() {
    <table>
        <tr>
            <th>User</th>
            <th>Group</th>
            <th>Other</th>
        </tr>
        <tr>
            <td>
                { api:checkbox("ur", substring($perms, 1, 1) = "r") }
                <label for="ur">read</label>
            </td>
            <td>
                { api:checkbox("gr", substring($perms, 4, 1) = "r") }
                <label for="gr">read</label>
            </td>
            <td>
                { api:checkbox("or", substring($perms, 7, 1) = "r") }
                <label for="or">read</label>
            </td>
        </tr>
        <tr>
            <td>
                { api:checkbox("uw", substring($perms, 2, 1) = "w") }
                <label for="uw">write</label>
            </td>
            <td>
                { api:checkbox("gw", substring($perms, 5, 1) = "w") }
                <label for="gw">write</label>
            </td>
            <td>
                { api:checkbox("ow", substring($perms, 8, 1) = "w") }
                <label for="ow">write</label>
            </td>
        </tr>
        <tr>
            <td>
                { api:checkbox("ux", substring($perms, 3, 1) = ("x", "s")) }
                <label for="ux">execute</label>
            </td>
            <td>
                { api:checkbox("gx", substring($perms, 6, 1) = ("x", "s")) }
                <label for="gx">execute</label>
            </td>
            <td>
                { api:checkbox("ox", substring($perms, 9, 1) = ("x", "t")) }
                <label for="ox">execute</label>
            </td>
        </tr>
        <tr>
            <td>
                { api:checkbox("us", substring($perms, 3, 1) = ("s", "S")) }
                <label for="us">setuid</label>
            </td>
            <td>
                { api:checkbox("gs", substring($perms, 6, 1) = ("s", "S")) }
                <label for="gs">setgid</label>
            </td>
            <td>
                { api:checkbox("ot", substring($perms, 9, 1) = ("t", "T")) }
                <label for="ot">sticky</label>
            </td>
        </tr>
    </table>
};

declare %private function api:get-users() as xs:string* {
    distinct-values(
        for $group in sm:list-groups()
        return
            try {
                sm:get-group-members($group)
            } catch * {
                ()
            }
    )
};

declare function api:get-properties($request as map(*)) {
    let $resourcesParam := $request?parameters?resources
    let $resources :=
        if ($resourcesParam instance of array(*)) then
            $resourcesParam?*
        else if ($resourcesParam instance of xs:string) then
            $resourcesParam
        else
            $resourcesParam
    let $props := api:merge-resource-properties($resources)
    let $users := api:get-users()
    let $html :=
        <form id="browsing-dialog-form" action="">
            <fieldset>
                {
                    if ($props("mime") != "") then
                        <div class="control-group">
                            <label for="mime">Mime:</label>
                            <input type="text" name="mime" value="{$props('mime')}"/>
                        </div>
                    else
                        ()
                }
                <div class="control-group">
                    <label for="owner">Owner:</label>
                    <select name="owner">
                    {
                        for $user in $users
                        order by $user collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
                        return
                            <option value="{$user}">
                            {
                                if ($user = $props("owner")) then
                                    attribute selected { "selected" }
                                else
                                    (),
                                $user
                            }
                            </option>
                    }
                    </select>
                </div>
                <div class="control-group">
                    <label for="group">Group:</label>
                    <select name="group">
                    {
                        for $group in sm:list-groups()
                        order by $group collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
                        return
                            <option value="{$group}">
                            {
                                if ($group = $props("group")) then
                                    attribute selected { "selected" }
                                else
                                    (),
                                $group
                            }
                            </option>
                    }
                    </select>
                </div>
            </fieldset>
            <fieldset>
                <legend>Permissions</legend>
                { api:get-permissions($props("permissions")) }
            </fieldset>
        </form>
    return
        roaster:response(200, "text/html", $html)
};

declare %private function api:permissions-from-body($body as map(*)) as xs:string? {
    let $perms := $body?permissions
    return
        if (exists($perms)) then
            let $rwx :=
                for $type in ("u", "g", "o")
                for $perm in ("r", "w", "x")
                let $key := $type || $perm
                let $param := 
                    if ($perms instance of map(*)) then
                        $perms?($key)
                    else
                        $body?($key)
                return
                    concat(
                        $type,
                        if ($param = true() or $param = "true" or $param = 1) then "+" else "-",
                        $perm
                    )
            let $special := (
                let $us := if ($perms instance of map(*)) then $perms?us else $body?us
                let $gs := if ($perms instance of map(*)) then $perms?gs else $body?gs
                let $ot := if ($perms instance of map(*)) then $perms?ot else $body?ot
                return (
                    concat("u", if ($us = true() or $us = "true" or $us = 1) then "+" else "-", "s"),
                    concat("g", if ($gs = true() or $gs = "true" or $gs = 1) then "+" else "-", "s"),
                    concat("o", if ($ot = true() or $ot = "true" or $ot = 1) then "+" else "-", "t")
                )
            )
            return
                string-join($rwx, ",") || "," || string-join($special, ",")
        else
            ()
};

declare function api:change-properties($request as map(*)) {
    let $body := $request?body
    let $resources :=
        if ($body?resources instance of array(*)) then
            $body?resources?*
        else
            $body?resources
    let $owner := $body?owner
    let $group := $body?group
    let $mime := $body?mime
    let $permFromBody := api:permissions-from-body($body)
    return
        try {
            for $resource in $resources
            let $uri := xs:anyURI($resource)
            return (
                if ($owner) then sm:chown($uri, $owner) else (),
                if ($group) then sm:chgrp($uri, $group) else (),
                if ($permFromBody) then sm:chmod($uri, $permFromBody) else (),
                if ($mime) then xmldb:set-mime-type($uri, $mime) else ()
            ),
            roaster:response(200, "application/json", map { "status": "ok" })
        } catch * {
            roaster:response(500, "application/json", map {
                "status": "fail",
                "message": $err:description
            })
        }
};

declare %private function api:mkcol-recursive($collection as xs:string, $components as xs:string*) as xs:string? {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            api:mkcol-recursive($newColl, subsequence($components, 2))
        )[last()]
    else
        ()
};

declare %private function api:mkcol($collection as xs:string, $path as xs:string) as xs:string? {
    api:mkcol-recursive($collection, tokenize($path, "/"))
};

declare %private function api:store-file($root as xs:string, $path as xs:string, $data as item()) as xs:string {
    if (matches($path, "/[^/]+$")) then
        let $split := analyze-string($path, "^(.*)/([^/]+)$")//fn:group/string()
        let $newCol := api:mkcol($root, $split[1])
        return
            xmldb:store($newCol, $split[2], $data)
    else
        xmldb:store($root, $path, $data)
};

declare %private function api:get-descriptors($zipPath as xs:string) as element()? {
    let $binary := util:binary-doc($zipPath)
    return
        if (exists($binary)) then
            let $dataCb := function($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) { $data }
            let $entryCb := function($path as xs:anyURI, $type as xs:string, $param as item()*) { $path = "expath-pkg.xml" }
            return
                compression:unzip($binary, $entryCb, (), $dataCb, ())
        else
            error(xs:QName("api:not-found"), "Could not deploy uploaded xar package: " || $zipPath || " not found.")
};

declare %private function api:deploy-xar($name as xs:string, $deploy as xs:boolean?) {
    if ($deploy and ends-with($name, ".xar")) then
        let $descriptors := api:get-descriptors($name)
        let $port := request:get-server-port()
        let $url := concat('http://localhost:', $port, "/exist/rest/", $name)
        let $appName := $descriptors/expath:package/@name
        return (
            repo:remove($appName),
            repo:install-and-deploy-from-db($name)
        )
    else
        ()
};

declare function api:upload($request as map(*)) {
    let $collection := head(($request?parameters?collection, "/db"))
    let $pathParam := $request?parameters?path
    let $deploy := $request?parameters?deploy = true()
    let $name := request:get-uploaded-file-name("file[]")
    let $data := request:get-uploaded-file-data("file[]")
    return
        if (empty($name) or empty($data)) then
            roaster:response(400, "application/json", map {
                "error": "Missing file upload"
            })
        else
            try {
                let $path := head(($pathParam, $name))
                let $storedPath := api:store-file($collection, $path, $data)
                let $mime := xmldb:get-mime-type(xs:anyURI($storedPath))
                let $components := analyze-string($storedPath, "^(.*)/([^/]+)$")//fn:group/string()
                let $size := 
                    if (exists($components)) then
                        xmldb:size($components[1], $components[2])
                    else
                        0
                let $_ := api:deploy-xar($storedPath, $deploy)
                return
                    roaster:response(200, "application/json", map {
                        "files": array {
                            map {
                                "name": $name,
                                "path": $storedPath,
                                "type": $mime,
                                "size": $size
                            }
                        }
                    })
            } catch * {
                roaster:response(500, "application/json", map {
                    "name": $name,
                    "error": $err:description
                })
            }
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