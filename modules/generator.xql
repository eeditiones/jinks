xquery version "3.1";

(:~
 : App generator module
 :)
module namespace generator="http://tei-publisher.com/library/generator";

declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "cpy.xql";
import module namespace inspect="http://exist-db.org/xquery/inspection";
import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace path="http://tei-publisher.com/jinks/path";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare variable $generator:NAMESPACE := "http://tei-publisher.com/library/generator";

declare variable $generator:ERROR_NOT_FOUND := xs:QName("generator:not-found");

declare variable $generator:PROFILES_ROOT := $config:app-root || "/profiles";

(:~
 : Generate or update an application using the provided configuration and settings.
 :
 : In the settings, property "overwrite" controls how files in an existing app are updated:
 : 
 : * "overwrite=all": the entire app is regenerated and then reinstalled
 : * "overwrite=update": files will be updated by the potentially newer versions from the profile –
 :   unless local modifications were applied by the user
 :
 : @param $settings general settings to control the generator
 : @param $config user-supplied configuration, which will overwrite the config.json in the profile
 :)
declare function generator:process($settings as map(*)?, $config as map(*)?) {
    let $context := generator:prepare($settings, $config)
    let $result :=
        for $profileName in $context?profiles?*
        let $adjContext := map:merge((
            $context,
            map {
                "source": $generator:PROFILES_ROOT || "/" || $profileName,
                "_noDeploy": map:contains($config, "profiles") or $settings?dry
            }
        ))
        return
            generator:write($adjContext, $generator:PROFILES_ROOT || "/" || $profileName, $config)
    let $postProcessed :=
        for $profileName in $context?profiles?*
        return
            generator:after-write($context, $result, $generator:PROFILES_ROOT || "/" || $profileName)
    let $nextStep := 
        if (not(repo:list() = $context?id)) then
            map {
                "message": "Package is not deployed yet. Deploy it by calling /api/generator/{profile}/deploy" ,
                "action": "DEPLOY"
            }
        else
            map {
                "message": "Package is already deployed. No action needed",
                "action": "NONE"
            }
    return
        map {
            "messages": array { $result, $postProcessed },
            "config": $context,
            "nextStep": $nextStep
        }
};

(:~
 : Prepare the configuration by merging all profile configurations, then for each profile, 
 : call the function annotated with "prepare" in the setup.xql, merging in any changes or additions
 : returned by that function.
 :
 : @param $settings general settings to control the generator
 : @param $config user-supplied configuration, which will overwrite the config.json in the profile
 :)
declare function generator:prepare($settings as map(*), $config as map(*)) {
    let $baseConfig := generator:config($settings, $config)
    let $mergedConfig :=
        fold-right($baseConfig?profiles?*, $baseConfig, function($profile, $config) {
            generator:call-prepare($generator:PROFILES_ROOT || "/" || $profile, $config)
        })
    return
        $mergedConfig
};

declare %private function generator:call-prepare($collection as xs:string, $baseConfig as map(*)?) {
    let $prepFunc := generator:find-callback($collection, "prepare")
    return
        if (exists($prepFunc)) then
            map:merge(($baseConfig, ($prepFunc?2)($baseConfig)))
        else
            $baseConfig
};

(:
 : Write the updated app to the DB.
 : If the app is not yet deployed, or the app needs to be redeployed the dep:deploy function needs to be called afterwards
 :)
declare %private function generator:write($context as map(*)?, $collection as xs:string, $appConfig as map(*)) {
    let $writeFunc := generator:find-callback($collection, "write")
    return
        if (exists($writeFunc)) then (
            ($writeFunc?2)($context),
            generator:save-config($context, $appConfig)
        ) else (
            cpy:copy-collection($context),
            generator:save-config($context, $appConfig)
        )
};

declare function generator:after-write($context as map(*), $result as map(*)*, $collection as xs:string) {
    generator:update-collection-config($context, $result),
    let $func := generator:find-callback($collection, "after-write")
    return
        if (exists($func)) then
            let $targetCollection := if ($context?_update) then path:get-package-target($context?id) else $context?target
            let $adjContext := map:merge((
                $context,
                map {
                    "base-uri": "http://localhost:" || request:get-server-port() ||
                        request:get-context-path() || "/apps/" ||
                        substring-after($targetCollection, repo:get-root()),
                    "target": $targetCollection
                }
            ))
            return
                ($func?2)($adjContext, $targetCollection)
        else
            ()
};

declare %private function generator:find-callback($collection as xs:string, $type as xs:string) {
    let $funcs :=
        if (util:binary-doc-available($collection || "/setup.xql")) then
            inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
        else
            ()
    return
        if (exists($funcs)) then
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
        else
            ()
};

declare function generator:find-setup($collection as xs:string) {
    if (util:binary-doc-available($collection || "/setup.xql")) then
        inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
    else
        ()
};

(:~
 : Returns the merged configuration for the given profile.
 :)
declare function generator:profile($name as xs:string) as map(*) {
    let $collection := $config:app-root || "/profiles/" || $name
    return
        generator:load-json($collection || "/config.json", map {})
        => generator:extends()
};

(:~
 : Assemble the configuration by merging the config.json of the source profile and the one stored in an already installed
 : application. $userConfig will overwrite the other two.
 :)
declare %private function generator:config($settings as map(*)?, $userConfig as map(*)?) {
    let $config := generator:extends($userConfig)
    let $installedPkg := 
        if ($config?id) then
            path:get-package-target(head(($userConfig?id, $config?id)))
        else
            ()
    let $tempTarget :=  $config:temp_directory || "/" || $config?pkg?abbrev
    let $config :=
        map:merge((
            $config,
            map {
                "target":
                    if ($settings?overwrite = "all") then
                        $tempTarget
                    else
                        head(($installedPkg, $tempTarget)),
                "_update": exists($installedPkg) and $settings?overwrite != "all",
                "_overwrite": $settings?overwrite,
                "_dry": $settings?dry,
                "template-suffix": "\.tpl"
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
declare function generator:extends($config as map(*)) {
    generator:extends($config, ())
};

declare %private function generator:extends($config as map(*), $profile as xs:string?) {
    if (exists($config?extends)) then
        let $extendedProfiles :=
            if ($config?extends instance of array(*)) then
                $config?extends?*
            else
                $config?extends
        let $extendedConfig :=
            for $profile in $extendedProfiles
            let $log := util:log("INFO", ("Loading extended profile: " || $profile))
            return
                generator:load-json($generator:PROFILES_ROOT || "/" || $profile || "/config.json", map {})
                => generator:extends($profile)
        return
            tmpl:merge-deep((
                $extendedConfig,
                map {
                    "profiles": array { $extendedConfig?profiles?*, $profile }
                },
                map:remove($config, "extends")
            ))
    else
        map:merge((
            $config,
            map {
                "profiles": array { $config?profiles?*, $profile }
            }
        ))
};

declare function generator:load-json($path as xs:string, $default as map(*)?) {
    if (util:binary-doc-available($path)) then
        json-doc($path)
    else
        $default
};

declare %private function generator:save-config($context as map(*), $appConfig as map(*)) {
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
        let $storeConfig := map:merge((
            (: map:entry("profiles", $context?profiles), :)
            $appConfig
        ))
        return (
            xmldb:store($context?target, "config.json", serialize($storeConfig, map { "method": "json", "indent": true()}))[2],
            xmldb:store($context?target, "context.json", serialize($context, map { "method": "json", "indent": true()}))[2]
        )
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
        json-doc($collection || "/.jinks.json")
    else
        map {}
};

declare %private function generator:update-collection-config($context as map(*), $result as map(*)*) {
    for $update in $result
    where $update?type="update" and $update?path = "collection.xconf"
    return
        xmldb:copy-resource($context?target, "collection.xconf", "/db/system/config/" || $context?target, "collection.xconf")
};

declare function generator:list-actions($context as map(*)) as array(*) {
    array {
        let $mcontext := generator:extends($context)
        let $actions :=
            for $profile in $mcontext?profiles?*
            return
                generator:find-callback($generator:PROFILES_ROOT || "/" || $profile, "action")
        for $action in $actions
        group by $name := function-name($action?2) => local-name-from-QName()
        return
            map {
                "name": $name,
                "description": $action[1]?1/value/string()
            }
    }
};

declare function generator:run-action($collection as xs:string, $actionName as xs:string) {
    util:log("INFO", "<jinks> Running action " || $actionName),
    let $configPath := path:resolve-path($collection, "config.json")
    let $config := generator:load-json($configPath, ())
    let $context := generator:extends($config)
    let $actions :=
        for $profile in $context?profiles?*
        let $callback := generator:find-callback($generator:PROFILES_ROOT || "/" || $profile, "action")
        return
            if (exists($callback) and local-name-from-QName(function-name($callback?2)) = $actionName) then
                $callback
            else
                ()
    for $action in $actions
    return
        $action?2($context)
};