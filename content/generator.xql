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
    let $context := generator:prepare($collection, $settings)
    for $profile in $context?profiles?*
    let $adjContext := map:merge((
        $context,
        map {
            "source": $profile,
            "noDeploy": $profile != $collection
        }
    ))
    return
        generator:write($adjContext, $profile)
};

declare function generator:prepare($collection as xs:string, $settings as map(*)) {
    let $baseConfig := generator:config($settings, $collection)
    let $mergedConfig :=
        fold-right($baseConfig?profiles?*, $baseConfig, function($profile, $config) {
            generator:call-prepare($profile, $config)
        })
    return
        $mergedConfig
};

declare %private function generator:call-prepare($collection as xs:string, $baseConfig as map(*)?) {
    let $setupFuncs :=
        if (util:binary-doc-available($collection || "/setup.xql")) then
            inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
        else
            ()
    return
        if (exists($setupFuncs)) then
            let $prepFunc := generator:find-callback($setupFuncs, "prepare")
            return
                if (exists($prepFunc)) then
                    map:merge(($baseConfig, ($prepFunc?2)($baseConfig)))
                else
                    $baseConfig
        else
            $baseConfig
};

declare %private function generator:write($context as map(*)?, $collection as xs:string) {
    let $setupFuncs :=
        if (util:binary-doc-available($collection || "/setup.xql")) then
            inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
        else
            ()
    return
        if (exists($setupFuncs)) then
            let $writeFunc := generator:find-callback($setupFuncs, "write")
            return
                if (exists($writeFunc)) then (
                    ($writeFunc?2)($context),
                    generator:save-config($context),
                    if ($context?update or $context?noDeploy) then
                        ()
                    else
                        cpy:deploy($context?target)
                ) else
                    error($generator:ERROR_NOT_FOUND, "No 'write' function found in " || $collection)
        else (
            cpy:copy-collection($context),
            generator:save-config($context),
            if ($context?update or $context?noDeploy) then
                ()
            else
                cpy:deploy($context?target)
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

declare %private function generator:config($settings as map(*)?, $collection as xs:string) {
    let $userConfig := 
        generator:load-json($collection || "/config.json", map {})
        => generator:extends($collection)
    let $installedPkg := 
        if ($userConfig?id) then
            generator:get-package-target($userConfig?id)
        else
            ()
    let $userConfig := 
        if ($installedPkg) then
            generator:load-json($installedPkg || "/config.json", $userConfig)
        else
            $userConfig
    let $templateMap := generator:load-template-map($installedPkg)
    let $config :=
        map:merge((
            $settings,
            $userConfig,
            map {
                "source": $collection,
                "target": 
                    head((
                        $installedPkg, 
                        "/db/system/temp/" || tokenize($collection, "/")[last()]
                    )),
                "update": exists($installedPkg) or empty($userConfig?id),
                "template-suffix": ".tpl",
                "_hashes": $templateMap
            })
        )
    return
        map:merge(($config, map { 
            "ignore": 
                distinct-values(($config?ignore, "setup.xql", "config.json"))
        }))
};

(:~
 : Merge the configurations of all inherited profiles. List of inherited profiles
 : is written to property "profiles".
 :)
declare %private function generator:extends($config as map(*), $collection as xs:string) {
    if (exists($config?extends)) then
        let $extendedConfig := 
            generator:load-json($config?extends || "/config.json", map {})
            => generator:extends($config?extends)
        return
            map:merge((
                $extendedConfig,
                map {
                    "profiles": array { $extendedConfig?profiles?*, $collection }
                },
                map:remove($config, "extends")
            ))
    else
        map:merge((
            $config,
            map {
                "profiles": array { $config?profiles?*, $collection }
            }
        ))
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
            if ($key = ("_hashes", "noDeploy")) then
                ()
            else
                map:entry($key, $value)
        })
    )
    return
        xmldb:store($context?target, "config.json", serialize($config, map { "method": "json", "indent": true()}))[2]
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
    if ($collection and util:binary-doc-available($collection || "/.generator.json")) then
        util:binary-doc($collection || "/.generator.json") => util:binary-to-string() => parse-json()
    else
        map {}
};