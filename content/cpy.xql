xquery version "3.1";

module namespace cpy="http://tei-publisher.com/xquery/copy";

import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare variable $cpy:ERROR_NOT_FOUND := xs:QName("cpy:not-found");
declare variable $cpy:ERROR_TEMPLATE := xs:QName("cpy:template");

declare function cpy:resolve-path($parent as xs:string, $relPath as xs:string) {
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
    return
        xmldb:store($context?config?target, $target, $expanded)
};

declare function cpy:copy-collection($context as map(*), $source as xs:string, $target as xs:string) {
    cpy:mkcol(cpy:resolve-path($context?config?target, $target), (), ())
};