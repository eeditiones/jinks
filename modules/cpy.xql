xquery version "3.1";

(:~
 : Functions for copying collections and resources. Handles potential conflicts
 : by computing a sha-256 hash for each resource.
 :)
module namespace cpy="http://tei-publisher.com/library/generator/copy";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $cpy:OVERWRITE_QUICK := "quick";
declare variable $cpy:OVERWRITE_ALL := "all";
declare variable $cpy:OVERWRITE_REINSTALL := "reinstall";

declare variable $cpy:ERROR_NOT_FOUND := xs:QName("cpy:not-found");
declare variable $cpy:ERROR_TEMPLATE := xs:QName("cpy:template");
declare variable $cpy:ERROR_CONFLICT := xs:QName("cpy:conflict");
declare variable $cpy:ERROR_PERMISSION := xs:QName("cpy:permission-denied");

declare variable $cpy:CONFLICT_DETAILS_MIMETYPES := (
    "text/html",
    "application/xml",
    "text/xml",
    "text/text",
    "text/plain",
    "application/json",
    "text/javascript",
    "text/css",
    "image/svg+xml",
    "application/xquery",
    "application/xslt+xml"
);

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

declare function cpy:expand-template($source as xs:string, $template as xs:string, $context as map(*)) {
    try {
        tmpl:process($template, $context, map {
            "plainText": true(),
            "resolver": cpy:resource-as-string($context, ?),
            "ignoreImports": head(($context?ignoreImports, true())),
            "ignoreUse": true(),
            "templates": $context?generator?templates
        })
    } catch * {
        error($cpy:ERROR_TEMPLATE, $err:description, map {
            "source": $source
        })
    }
};

declare function cpy:copy-template($context as map(*), $source as xs:string, $target as xs:string) {
    let $template := cpy:resource-as-string($context, $source)
    let $expanded := cpy:expand-template($source, $template?content, $context)
    let $path := path:resolve-path($context?target, $target)
    let $relPath := substring-after($path, $context?target || "/")
    return
        cpy:overwrite($context, $relPath, $source, function() { $expanded }, function() {(
            xmldb:store(path:parent($path), path:basename($path), $expanded),
            sm:chown(xs:anyURI($path), $context?pkg?user?name),
            sm:chgrp(xs:anyURI($path), $context?pkg?user?group),
            sm:chmod(xs:anyURI($path), $context?pkg?permissions)
        )[1]})
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
                )
        })
};

(:
 : Concatenate multiple resources (with string content) into a single file.
 :
 : @param $context The context map.
 : @param $sourcePaths The relative paths of the resources to concatenate.
 : @param $target The relative path of the target file.
 : @return The result of the overwrite operation.
 :)
declare function cpy:concat($context as map(*), $sourcePaths as xs:string+, $target as xs:string) {
    let $targetPath := path:resolve-path($context?target, $target)
    let $content := string-join(
        for $path in $sourcePaths
        return
            cpy:resource-as-string($context, $path)?content
        ,
        "&#10;&#10;"
    )
    let $targetPath := path:resolve-path($context?target, $target)
    let $_ := util:log("info", "Concatenated " || $targetPath || " from " || string-join($sourcePaths, ", "))
    return
        cpy:overwrite($context, $target, string-join($sourcePaths, "; "), function() { $content }, function() {
            xmldb:store(path:parent($targetPath), path:basename($targetPath), $content)
        })
};

declare function cpy:copy-collection($context as map(*)) {
    cpy:copy-collection($context, "", "", ())
};

declare function cpy:copy-collection($context as map(*), $source as xs:string, $target as xs:string) {
    cpy:copy-collection($context, $source, $target, ())
};

declare function cpy:copy-collection($context as map(*), $source as xs:string, $target as xs:string, $regex as xs:string?) {
    path:mkcol($context, $target),
    let $absSource := path:resolve-path($context?source, $source)
    return (
        for $resource in xmldb:get-child-resources($absSource)
        where empty($regex) or matches($resource, $regex)
        return
            if (matches($resource, $context?template-suffix)) then
                let $template := cpy:resource-as-string($context, $absSource || "/" || $resource)
                let $expanded := cpy:expand-template($resource, $template?content, $context)
                let $targetName := replace($resource, $context?template-suffix, "")
                let $collection := path:resolve-path($context?target, $target)
                let $relPath := substring-after($collection || "/" || $targetName, $context?target || "/")
                return
                    cpy:overwrite($context, $relPath, $absSource || "/" || $resource, function() { $expanded }, function() {
                        xmldb:store($collection, $targetName, $expanded)
                    })
            else
                cpy:copy-resource($context, $source || "/" || $resource, $target || "/" || $resource),
        for $childColl in xmldb:get-child-collections($absSource)
        return
            cpy:copy-collection($context, $source || "/" || $childColl, $target || "/" || $childColl, $regex)
    )
};

(:~
 : Determine if the file corresponding to $relPath can be overwritten, and if yes, call the $callback
 : function. To detect conflicts, a hash key is computed and stored into .jinks.json.
 :)
declare %private function cpy:overwrite($context as map(*), $relPath as xs:string, $sourcePath as xs:string,
    $content as function(*), $callback as function(*)) {
    if (
        (some $skipPath in $context?skip?* satisfies matches($relPath, $skipPath)) or
        (some $skipPath in $context?skipSource?* satisfies matches($sourcePath, $skipPath))
    ) then
        ()
    (: overwrite, but do not check or store hash :)
    else if ($context?force-overwrite or (some $ignorePath in $context?ignore?* satisfies matches($relPath, $ignorePath))) then
        $callback()[2]
    (: we're updating an already installed app :)
    else if ($context?_update) then
        let $path := path:resolve-path($context?target, $relPath)
        let $mime := xmldb:get-mime-type(xs:anyURI($path))
        let $expectedHash := cpy:load-hash($context, $relPath)
        let $lastModified := xmldb:last-modified(path:parent($sourcePath), path:basename($sourcePath))
        return
            (: Check timestamp of .jinks.json first to determine if source was modified since last run :)
            (: Templated source files should always be updated though :)
            if (
                $context?_overwrite != $cpy:OVERWRITE_ALL and
                not(matches($sourcePath, $context?template-suffix)) and
                cpy:file-exists($path) and
                exists($context?_lastModified) and
                $context?_lastModified >= $lastModified and
                (: If a conflicting file was marked to be overwritten, it will not have a hash :)
                exists($expectedHash)
            ) then
                ()
            else
                let $currentHash := cpy:hash($path)
                let $incomingContent := $content()
                return
                    (: Check if there have been changes to the file since it was installed :)
                    if (empty($currentHash) or empty($expectedHash) or $currentHash = $expectedHash) then
                        let $contentHash := cpy:hash($incomingContent, $mime)
                        return
                            (: Still update if overwrite="full", the file was not there last time,
                            : or the incoming content is different :)
                            if (empty($expectedHash)
                                or $contentHash != $expectedHash) then (
                                    map {
                                        "type": "update",
                                        "path": $relPath,
                                        "source": $sourcePath
                                    },
                                    let $stored := $callback()
                                    return
                                        cpy:save-hash($context, $relPath, cpy:hash($stored))
                                )
                            else
                                ()
                    else
                        (: conflict detected :)
                        map {
                            "type": "conflict",
                            "path": $relPath,
                            "source": $path,
                            "hash": map {
                                "original": $expectedHash,
                                "actual": $currentHash
                            },
                            "mime": $mime,
                            "incoming":
                                if ($mime = $cpy:CONFLICT_DETAILS_MIMETYPES) then
                                    $incomingContent
                                else
                                    ()
                        }
    (: fresh install of new app package :)
    else if ($context?_dry) then
        map {
            "type": "write",
            "path": $relPath
        }
    else
        let $stored := $callback()
        return
            cpy:save-hash($context, $relPath, cpy:hash($stored))
};

declare %private function cpy:hash($path as xs:string) {
    let $content :=
        if (util:binary-doc-available($path)) then
            util:binary-doc($path) => util:binary-to-string()
        else if (doc-available($path)) then
            doc($path) => serialize()
        else
            ()
    let $mime := xmldb:get-mime-type(xs:anyURI($path))
    return
        cpy:hash($content, $mime)
};

declare %private function cpy:hash($content as xs:string?, $mime as xs:string?) {
    if (exists($content)) then
        (: Remove whitespace and XML version tags. These are not relevant for the actual hash :)
        (: TODO: self-closing elements are also not important, neither is attribute order. They can have the same hash :)
        if ($mime = ("text/html", "application/xml")) then
            util:hash(replace($content, "(<?[xX][mM][lL](^\?)*?>)|[\s\n\r]+", " "), "sha-256")
        else
            util:hash($content, "sha-256")
    else
        ()
};

declare %private function cpy:file-exists($path as xs:string) {
    doc-available($path) or util:binary-doc-available($path)
};
