xquery version "3.1";

(:~
 : App generator module
 :)
module namespace generator="http://tei-publisher.com/library/generator";

declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace inspect="http://exist-db.org/xquery/inspection";
import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";

declare variable $generator:NAMESPACE := "http://tei-publisher.com/library/generator";

declare variable $generator:ERROR_NOT_FOUND := xs:QName("generator:not-found");

declare variable $generator:PROFILES_ROOT := $config:app-root || "/profiles";

declare function generator:process($profile as xs:string) {
    generator:process($profile, (), ())
};

(:~
 : Generate or update an application using the provided profile, settings and configuration.
 :
 : In the settings, property "overwrite" controls how files in an existing app are updated:
 : 
 : * "overwrite=all": the entire app is regenerated and then reinstalled
 : * "overwrite=update": files will be updated by the potentially newer versions from the profile –
 :   unless local modifications were applied by the user
 :
 : @param $profile the name of the profile to apply
 : @param $settings general settings to control the generator
 : @param $config user-supplied configuration, which will overwrite the config.json in the profile
 :)
declare function generator:process($profile as xs:string, $settings as map(*)?, $config as map(*)?) {
    let $context := generator:prepare($generator:PROFILES_ROOT || "/" || $profile, $settings, $config)
    let $result :=
        for $profileName in $context?profiles?*
        let $adjContext := map:merge((
            $context,
            map {
                "source": $generator:PROFILES_ROOT || "/" || $profileName,
                "_noDeploy": $profileName != $profile or $settings?dry
            }
        ))
        return
            generator:write($adjContext, $generator:PROFILES_ROOT || "/" || $profileName)
    return
        map {
            "messages": array { $result },
            "config": $context
        }
};

declare function generator:prepare($collection as xs:string, $settings as map(*), $config as map(*)) {
    let $baseConfig := generator:config($collection, $settings, $config)
    let $mergedConfig :=
        fold-right($baseConfig?profiles?*, $baseConfig, function($profile, $config) {
            generator:call-prepare($generator:PROFILES_ROOT || "/" || $profile, $config)
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
                    if ($context?_update or $context?_noDeploy) then
                        ()
                    else
                        cpy:deploy($context?target)
                ) else
                    error($generator:ERROR_NOT_FOUND, "No 'write' function found in " || $collection)
        else (
            cpy:copy-collection($context),
            generator:save-config($context),
            if ($context?_update or $context?_noDeploy) then
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

declare function generator:profile($name as xs:string) {
    let $collection := $config:app-root || "/profiles/" || $name
    return
        generator:load-json($collection || "/config.json", map {})
        => generator:extends($collection)
};

(:~
 : Assemble the configuration by merging the config.json of the source profile and the one stored in an already installed
 : application. $userConfig will overwrite the other two.
 :)
declare %private function generator:config($collection as xs:string, $settings as map(*)?, $userConfig as map(*)?) {
    let $profileConfig := 
        generator:load-json($collection || "/config.json", map {})
        => generator:extends($collection)
    let $installedPkg := 
        if ($profileConfig?id) then
            generator:get-package-target(head(($userConfig?id, $profileConfig?id)))
        else
            ()
    let $installedConfig := 
        if ($installedPkg) then
            generator:load-json($installedPkg || "/config.json", $profileConfig)
        else
            $profileConfig
    let $templateMap := generator:load-template-map($installedPkg)
    let $mergedConfig := 
        generator:merge-deep((
            $installedConfig,
            $userConfig
        ))
    let $tempTarget := "/db/system/temp/" || $mergedConfig?pkg?abbrev
    let $config :=
        map:merge((
            $mergedConfig,
            map {
                "source": $collection,
                "target":
                    if ($settings?overwrite = "all") then
                        $tempTarget
                    else
                        head(($installedPkg, $tempTarget)),
                "_update": exists($installedPkg) and $settings?overwrite != "all",
                "_overwrite": $settings?overwrite,
                "_dry": $settings?dry,
                "template-suffix": ".tpl",
                "_hashes": $templateMap
            })
        )
    return
        map:merge(($config, map { 
            "skip": distinct-values(($config?skip?*, "setup.xql", "config.json"))
        }))
};

(:~
 : Merge the configurations of all inherited profiles. List of inherited profiles
 : is written to property "profiles".
 :)
declare %private function generator:extends($config as map(*), $collection as xs:string) {
    let $profileName := replace($collection, "^(?:" || $generator:PROFILES_ROOT || "/)?(.*)$", "$1")
    return
        if (exists($config?extends)) then
            let $extendedConfig := 
                generator:load-json($generator:PROFILES_ROOT || "/" || $config?extends || "/config.json", map {})
                => generator:extends($config?extends)
            return
                generator:merge-deep((
                    $extendedConfig,
                    map {
                        "profiles": array { $extendedConfig?profiles?*, $profileName }
                    },
                    map:remove($config, "extends")
                ))
        else
            map:merge((
                $config,
                map {
                    "profiles": array { $config?profiles?*, $profileName }
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
    if ($context?_dry) then
        ()
    else
        let $config := map:merge(
            map:for-each($context, function($key, $value) {
                if (starts-with($key, "_") or $key = "source" or $key = "target") then
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

declare function generator:get-package-descriptor($uri as xs:string?) {
    if (not(repo:list()[. = $uri])) then
        ()
    else
        repo:get-resource($uri, "expath-pkg.xml")
        => util:binary-to-string()
        => parse-xml()
};

declare %private function generator:load-template-map($collection as xs:string?) {
    if ($collection and util:binary-doc-available($collection || "/.jinks.json")) then
        util:binary-doc($collection || "/.jinks.json") => util:binary-to-string() => parse-json()
    else
        map {}
};

declare function generator:merge-deep($maps as map(*)*) {
    map:merge(
        for $key in distinct-values($maps ! map:keys(.))
        let $mapsWithKey := filter($maps, function($map) { map:contains($map, $key) })
        let $newVal :=
            if ($mapsWithKey[1]($key) instance of map(*)) then
                generator:merge-deep($mapsWithKey ! .($key))
            else if ($key = ("odds", "ignore")) then
                array {
                    distinct-values($mapsWithKey ! .($key)?*)
                }
            else
                $mapsWithKey[last()]($key)
        return
            map:entry($key, $newVal)
    )
};