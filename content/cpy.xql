xquery version "3.1";

module namespace cpy="http://tei-publisher.com/library/generator/copy";

import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $cpy:ERROR_NOT_FOUND := xs:QName("cpy:not-found");
declare variable $cpy:ERROR_TEMPLATE := xs:QName("cpy:template");

declare %private function cpy:resolve-path($parent as xs:string, $relPath as xs:string) as xs:string {
    if (starts-with($relPath, "/db")) then
        $relPath
    else
        replace($parent || "/" || $relPath, "/{2,}", "/")
};

declare %private function cpy:resource-as-string($context as map(*), $relPath as xs:string) as xs:string? {
    let $path := cpy:resolve-path($context?config?source, $relPath)
    return
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            error($cpy:ERROR_NOT_FOUND, "Input file " || $path || " not found")
};

declare %private function cpy:expand-template($template as xs:string, $context as map(*)) {
    try {
        tmpl:process($template, $context, true(), cpy:resource-as-string($context, ?))
    } catch * {
        error($cpy:ERROR_TEMPLATE, $err:description)
    }
};

declare %private function cpy:mkcol-recursive($collection, $components, $userData as xs:string*, $permissions as xs:string?) {
    if (exists($components)) then
        let $permissions :=
            if ($permissions) then
                cpy:set-execute-bit($permissions)
            else
                "rwxr-x---"
        let $newColl := xs:anyURI(concat($collection, "/", $components[1]))
        return (
            if (not(xmldb:collection-available($newColl))) then
                xmldb:create-collection($collection, $components[1])
            else
                (),
            cpy:mkcol-recursive($newColl, subsequence($components, 2), $userData, $permissions)
        )
    else
        ()
};

declare function cpy:mkcol($path, $userData as xs:string*, $permissions as xs:string?) {
    let $path := if (starts-with($path, "/db/")) then substring-after($path, "/db/") else $path
    return
        cpy:mkcol-recursive("/db", tokenize($path, "/"), $userData, $permissions)
};

declare function cpy:set-execute-bit($permissions as xs:string) {
    replace($permissions, "(..).(..).(..).", "$1x$2x$3x")
};

declare function cpy:copy-template($context as map(*), $source as xs:string, $target as xs:string) {
    let $template := cpy:resource-as-string($context, $source)
    let $expanded := cpy:expand-template($template, $context)
    let $path := $context?config?target || "/" || $target
    return (
        xmldb:store($context?config?target, $target, $expanded),
        sm:chown($path, $context?pkg?user?name),
        sm:chgrp($path, $context?pkg?user?group),
        sm:chmod($path, $context?pkg?permissions)
    )
};

declare function cpy:copy-resource($context as map(*), $source as xs:string, $target as xs:string) {
    let $sourcePath := cpy:resolve-path($context?config?source, $source)
    let $targetPath := cpy:resolve-path($context?config?target, $target)
    return
    xmldb:copy-resource(
        replace($sourcePath, "^(.*?)/[^/]+$", "$1"),
        replace($sourcePath, "^.*?/([^/]+)$", "$1"),
        replace($targetPath, "^(.*?)/[^/]+$", "$1"),
        replace($targetPath, "^.*?/([^/]+)$", "$1")
    )
};

declare function cpy:copy-collection($context as map(*)) {
    cpy:copy-collection($context, "", "")
};

declare function cpy:copy-collection($context as map(*), $source as xs:string, $target as xs:string) {
    cpy:mkcol(
        cpy:resolve-path($context?config?target, $target), 
        ($context?pkg?user?name, $context?pkg?user?group), 
        $context?pkg?permissions
    ),
    let $absSource := cpy:resolve-path($context?config?source, $source)
    return (
        for $resource in xmldb:get-child-resources($absSource)
        return
            if (matches($resource, $context?config?template-suffix)) then
                let $template := cpy:resource-as-string($context, $absSource || "/" || $resource)
                let $expanded := cpy:expand-template($template, $context)
                let $targetName := replace($resource, $context?config?template-suffix, "")
                return
                    xmldb:store(cpy:resolve-path($context?config?target, $target), $targetName, $expanded)
            else
                cpy:copy-resource($context, $source || "/" || $resource, $target || "/" || $resource),
        for $childColl in xmldb:get-child-collections($absSource)
        return
            cpy:copy-collection($context, $source || "/" || $childColl, $target || "/" || $childColl)
    )
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
        xmldb:store("/db/system/repo", $name, $xar, "application/zip")
};

declare function cpy:deploy($collection as xs:string) {
    let $expathConf := collection($collection)/expath:package
    return
        cpy:deploy($collection, $expathConf)
};

declare function cpy:deploy($collection as xs:string, $expathConf as element()) {
    let $pkg := cpy:package($collection, $expathConf)
    let $name := $expathConf/@name/string()
    return (
        if (index-of(repo:list(), $name)) then (
            repo:undeploy($name),
            repo:remove($name)
        ) else
            (),
        repo:install-and-deploy-from-db($pkg),
        xmldb:remove($collection)
    )
};