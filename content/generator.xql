xquery version "3.1";

module namespace generator="http://tei-publisher.com/library/generator";

declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace inspect="http://exist-db.org/xquery/inspection";

declare variable $generator:NAMESPACE := "http://tei-publisher.com/library/generator";

declare variable $generator:ERROR_NOT_FOUND := xs:QName("generator:not-found");

declare function generator:process($collection as xs:string) {
    generator:process($collection, ())
};

declare function generator:process($collection as xs:string, $settings as map(*)?) {
    let $setupFuncs :=
        if (util:binary-doc-available($collection || "/setup.xql")) then
            inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
        else
            ()
    let $context := generator:prepare($collection, $setupFuncs, $settings)
    return
        generator:write($context, $collection, $setupFuncs)
};

declare %private function generator:prepare($collection as xs:string, $setupFuncs as function(*)*,
    $settings as map(*)?) {
    if (exists($setupFuncs)) then
        let $prepFunc := generator:find-callback($setupFuncs, "prepare")
        let $config := generator:config($settings, $collection, $prepFunc?1/value[1])
        return
            if (exists($prepFunc)) then
                map:merge(($config, ($prepFunc?2)($config)))
            else
                $config
    else
        generator:config($settings, $collection, ())
};

declare %private function generator:write($context as map(*)?, $collection as xs:string, $setupFuncs as function(*)*) {
    if (exists($setupFuncs)) then
        let $writeFunc := generator:find-callback($setupFuncs, "write")
        return
            if (exists($writeFunc)) then (
                ($writeFunc?2)($context),
                generator:save-config($context),
                if ($context?_config?update) then
                    ()
                else
                    cpy:deploy($context?_config?target)
            ) else
                error($generator:ERROR_NOT_FOUND, "No 'write' function found in " || $collection)
    else (
        cpy:copy-collection($context),
        generator:save-config($context),
        if ($context?_config?update) then
            ()
        else
            cpy:deploy($context?_config?target)
    )
};

declare %private function generator:find-callback($funcs as function(*)*, $type as xs:string) {
    fold-right($funcs, (), function($func, $in) {
        if (exists($in)) then
            $in
        else
            let $desc := inspect:inspect-function($func)
            let $anno := 
                $desc/annotation[@namespace = $generator:NAMESPACE]
                    [replace($desc/annotation/@name, "^.*?:(.*)$", "$1") = $type]
            return
                if ($anno) then
                    [$anno, $func]
                else
                    ()
    })
};

declare %private function generator:config($settings as map(*)?, $collection as xs:string, $target as xs:string?) {
    let $userConfig := generator:load-json($collection || "/config.json", map {})
    let $installedPkg := generator:get-package-target($userConfig?id)
    let $userConfig := generator:load-json($installedPkg || "/config.json", $userConfig)
    let $templateMap := generator:load-template-map($installedPkg)
    let $config :=
        map:merge((
            $settings,
            $userConfig,
            map {
                "_config": map {
                    "source": $collection,
                    "target": 
                        head((
                            $installedPkg, 
                            head(($target, "/db/system/temp/" || tokenize($collection, "/")[last()]))
                        )),
                    "update": exists($installedPkg),
                    "template-suffix": ".tpl"
                },
                "_hashes": $templateMap
            })
        )
    return
        map:merge(($config, map { 
            "ignore": 
                distinct-values(($config?ignore, "setup.xql", "config.json"))
        }))
};

declare function generator:load-json($path as xs:string, $default as map(*)) {
    if (util:binary-doc-available($path)) then
        util:binary-doc($path)
        => util:binary-to-string()
        => parse-json()
    else
        $default
};

declare %private function generator:save-config($context as map(*)) {
    let $config := map:merge(
        map:for-each($context, function($key, $value) {
            if ($key = ("_hashes")) then
                ()
            else
                map:entry($key, $value)
        })
    )
    return
        xmldb:store($context?_config?target, "config.json", serialize($config, map { "method": "json", "indent": true()}))[2]
};

declare function generator:get-package-target($uri as xs:string?) {
    if (not(repo:list()[. = $uri])) then
        ()
    else
        let $repoXML := 
            repo:get-resource($uri, "repo.xml")
            => util:binary-to-string()
            => parse-xml()
        return
            if ($repoXML//repo:target) then
                repo:get-root() || $repoXML//repo:target
            else
                ()
};

declare %private function generator:load-template-map($collection as xs:string?) {
    if (util:binary-doc-available($collection || "/.generator.json")) then
        util:binary-doc($collection || "/.generator.json") => util:binary-to-string() => parse-json()
    else
        map {}
};