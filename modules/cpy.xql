xquery version "3.1";

(:~
 : Functions for copying collections and resources. Handles potential conflicts
 : by computing a sha-256 hash for each resource.
 :)
module namespace cpy="http://tei-publisher.com/library/generator/copy";

import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $cpy:ERROR_NOT_FOUND := xs:QName("cpy:not-found");
declare variable $cpy:ERROR_TEMPLATE := xs:QName("cpy:template");
declare variable $cpy:ERROR_CONFLICT := xs:QName("cpy:conflict");
declare variable $cpy:ERROR_PERMISSION := xs:QName("cpy:permission-denied");

declare %private function cpy:save-hash($context as map(*), $relPath as xs:string, $hash as xs:string) {
    let $jsonFile := path:resolve-path($context?target, ".jinks.json")
    let $json :=
        if (util:binary-doc-available($jsonFile)) then
            json-doc($jsonFile)
        else
            map {}
    let $updated := map:merge((
        $json,
        map {
            $relPath: $hash
        }
    )) => serialize(map { "method": "json", "indent": true() })
    return
        xmldb:store($context?target, ".jinks.json", $updated, "application/json")[2]
};

declare %private function cpy:load-hash($context as map(*), $relPath as xs:string) {
    let $jsonFile := path:resolve-path($context?target, ".jinks.json")
    return
        if (util:binary-doc-available($jsonFile)) then
            json-doc($jsonFile)($relPath)
        else
            ()
};

declare function cpy:resource-as-string($context as map(*), $relPath as xs:string) as map(*) {
    let $path := path:resolve-path($context?source, $relPath)
    let $content :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            error($cpy:ERROR_NOT_FOUND, "Input file " || $path || " not found")
    return
        map {
            "path": $path,
            "content": $content
        }
};

declare function cpy:expand-template($template as xs:string, $context as map(*)) {
    try {
        tmpl:process($template, $context, map {
            "plainText": true(), 
            "resolver": cpy:resource-as-string($context, ?),
            "ignoreImports": true()
        })
    } catch * {
        error($cpy:ERROR_TEMPLATE, $err:description)
    }
};

declare function cpy:copy-template($context as map(*), $source as xs:string, $target as xs:string) {
    let $template := cpy:resource-as-string($context, $source)
    let $expanded := cpy:expand-template($template?content, $context)
    let $path := path:resolve-path($context?target, $target)
    let $relPath := substring-after($path, $context?target || "/")
    return 
        cpy:overwrite($context, $relPath, $source, $expanded, function() {(
            xmldb:store($context?target, $target, $expanded),
            sm:chown($path, $context?pkg?user?name),
            sm:chgrp($path, $context?pkg?user?group),
            sm:chmod($path, $context?pkg?permissions)
        )[5]})
};

declare function cpy:copy-resource($context as map(*), $source as xs:string, $target as xs:string) {
    let $sourcePath := path:resolve-path($context?source, $source)
    let $targetPath := path:resolve-path($context?target, $target)
    let $relPath := substring-after($targetPath, $context?target || "/")
    return
        cpy:overwrite($context, $relPath, $sourcePath, function() {
            cpy:resource-as-string($context, $sourcePath)?content
        }, function() {
            xmldb:copy-resource(
                path:parent($sourcePath),
                path:basename($sourcePath),
                path:parent($targetPath),
                path:basename($targetPath)
            )[2]
        })
};

declare function cpy:copy-collection($context as map(*)) {
    cpy:copy-collection($context, "", "")
};

declare function cpy:copy-collection($context as map(*), $source as xs:string, $target as xs:string) {
    path:mkcol($context, $target),
    let $absSource := path:resolve-path($context?source, $source)
    return (
        for $resource in xmldb:get-child-resources($absSource)
        return
            if (matches($resource, $context?template-suffix)) then
                let $template := cpy:resource-as-string($context, $absSource || "/" || $resource)
                let $expanded := cpy:expand-template($template?content, $context)
                let $targetName := replace($resource, $context?template-suffix, "")
                let $collection := path:resolve-path($context?target, $target)
                let $relPath := substring-after($collection || "/" || $targetName, $context?target || "/")
                return
                    cpy:overwrite($context, $relPath, $absSource || "/" || $resource, function() { $expanded }, function() {
                        xmldb:store($collection, $targetName, $expanded)[2]
                    })
            else
                cpy:copy-resource($context, $source || "/" || $resource, $target || "/" || $resource),
        for $childColl in xmldb:get-child-collections($absSource)
        return
            cpy:copy-collection($context, $source || "/" || $childColl, $target || "/" || $childColl)
    )
};

(:~
 : Determine if the file corresponding to $relPath can be overwritten, and if yes, call the $callback
 : function. To detect conflicts, a hash key is computed and stored into .jinks.json.
 :)
declare %private function cpy:overwrite($context as map(*), $relPath as xs:string, $sourcePath as xs:string, 
    $content as function(*), $callback as function(*)) {
    if ($relPath = $context?skip) then
        ()
    (: overwrite, but do not check or store hash :)
    else if ($relPath = $context?ignore) then
        $callback()
    (: we're updating an already installed app :)
    else if ($context?_update) then
        let $path := path:resolve-path($context?target, $relPath)
        let $currentContent :=
            if (util:binary-doc-available($path)) then
                util:binary-doc($path) => util:binary-to-string()
            else
                doc($path) => serialize()
        let $currentHash := cpy:hash($currentContent)
        let $expectedHash := cpy:load-hash($context, $relPath)
        return
            (: Check if there have been changes to the file since it was installed :)
            if (empty($expectedHash) or $currentHash = $expectedHash) then
                let $contentHash := cpy:hash($content())
                return
                    (: Still update if overwrite="update", the file was not there last time,
                    : or the incoming content is different :)
                    if (empty($expectedHash) or $context?_overwrite = "update"
                        or $contentHash != $expectedHash) then (
                            map {
                                "type": "update",
                                "path": $relPath,
                                "source": $sourcePath
                            },
                            cpy:save-hash($context, $relPath, $contentHash),
                            $callback()
                        )
                    else
                        ()
            else
                (: conflict detected :)
                map {
                    "type": "conflict",
                    "path": $relPath,
                    "hash": map {
                        "original": $expectedHash,
                        "actual": $currentHash
                    }
                }
    (: fresh install of new app package :)
    else if ($context?_dry) then
        map {
            "type": "write",
            "path": $relPath
        }
    else (
        cpy:save-hash($context, $relPath, cpy:hash($content())),
        $callback()
    )
};

declare %private function cpy:hash($content as xs:string) {
    util:hash(replace($content, "[\s\n\r]+", " "), "sha-256")
};

declare %private function cpy:scan-resources($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) {
    $func($root, ()),
    if (sm:has-access($root, "rx")) then
        for $child in xmldb:get-child-resources($root)
        return
            $func($root, xs:anyURI($root || "/" || $child))
    else
        (),
    if (sm:has-access($root, "rx")) then
        for $child in xmldb:get-child-collections($root)
        return
            cpy:scan-resources(xs:anyURI($root || "/" || $child), $func)
    else
        ()
};

declare %private function cpy:zip-entries($app-collection as xs:string) {
    (: compression:zip doesn't seem to store empty collections, so we'll scan for only resources :)
    cpy:scan-resources(xs:anyURI($app-collection), function($collection as xs:anyURI, $resource as xs:anyURI?) {
        if (exists($resource)) then
            let $relative-path := substring-after($resource, $app-collection || "/")
            return
                if (starts-with($relative-path, "transform/")) then
                    ()
                else if (util:binary-doc-available($resource)) then
                    <entry name="{$relative-path}" type="uri">{$resource}</entry>
                else
                    <entry name="{$relative-path}" type="text">
                    {
                        serialize(doc($resource), map { "indent": false() })
                    }
                    </entry>
        else
            ()
    })
};

declare function cpy:package($collection as xs:string, $expathConf as element()) {
    let $name := concat($expathConf/@abbrev, "-", $expathConf/@version, ".xar")
    let $entries := cpy:zip-entries($collection)
    let $xar := compression:zip($entries, true())
    return
        try {
            xmldb:store("/db/system/temp", $name, $xar, "application/zip")
        } catch * {
            error($cpy:ERROR_PERMISSION, "Permission denied to store package '" || $name || "'")
        }
};

declare function cpy:deploy($collection as xs:string) {
    let $expathConf := collection($collection)/expath:package
    let $null := cpy:deploy($collection, $expathConf)
    return
        ()
};

declare function cpy:deploy($collection as xs:string, $expathConf as element()) {
    let $pkg := cpy:package($collection, $expathConf)
    let $name := $expathConf/@name/string()
    return (
        cpy:undeploy($name),
        repo:install-and-deploy-from-db($pkg),
        xmldb:remove($collection)
    )
};

declare function cpy:undeploy($id as xs:string) {
    if (index-of(repo:list(), $id)) then (
        repo:undeploy($id),
        repo:remove($id)
    ) else
        ()
};