xquery version "3.1";

(:~
 : App generator module
 :)
module namespace generator="http://tei-publisher.com/library/generator";

declare namespace repo="http://exist-db.org/xquery/repo";

import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "cpy.xql";
import module namespace inspect="http://exist-db.org/xquery/inspection";
import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare variable $generator:NAMESPACE := "http://tei-publisher.com/library/generator";

declare variable $generator:ERROR_NOT_FOUND := xs:QName("generator:not-found");

declare variable $generator:PROFILES_ROOT := $config:app-root || "/profiles";

declare function generator:profile-path($name as xs:string) {
    let $internalPath := $generator:PROFILES_ROOT || "/" || $name
    return
        if (xmldb:collection-available($internalPath)) then
            $internalPath
        else
            for $collection in xmldb:get-child-collections(repo:get-root())
            where $collection = $name
            return
                repo:get-root() || "/" || $collection
};

(:~
 : Generate or update an application using the provided configuration and settings.
 :
 : In the settings, property "overwrite" controls how files in an existing app are updated:
 : 
 : * "overwrite=quick": check last modified date of source and if newer, check if content has changed
 : * "overwrite=all": ignore last modified date, enforce content check
 : * "overwrite=reinstall": the entire app is regenerated and then reinstalled
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
                "source": generator:profile-path($profileName),
                "_noDeploy": map:contains($config, "profiles") or $settings?dry,
                "_lastModified": $settings?last-modified
            }
        ))
        return
            generator:write($adjContext, generator:profile-path($profileName), $config)
    let $postProcessed :=
        for $profileName in $context?profiles?*
        return
            generator:after-write($context, $result, generator:profile-path($profileName))
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
            "messages": array { generator:filter-conflicts($result), $postProcessed },
            "config": $context,
            "nextStep": $nextStep
        }
};

(:~
 : Clean up the list of conflicts: if a file is copied from different profiles, keep only the last conflict message.
 :)
declare %private function generator:filter-conflicts($messages as map(*)*) {
    if (empty($messages)) then
        ()
    else
        let $next := head($messages)
        let $tail := tail($messages)
        let $laterMessages := filter($tail, function($msg) { 
            $msg?type = "conflict" and $msg?path = $next?path
        })
        return
            if (exists($laterMessages)) then
                generator:filter-conflicts($tail)
            else (
                $next,
                generator:filter-conflicts($tail)
            )
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
    let $dependencies := generator:load-json($config:app-root || "/config/package.json", map {})
    let $cdnUrls := 
        if (map:size($dependencies) > 0) then
            map {
                "swagger-ui-css": config:cdn-url($dependencies, 'swagger-ui-dist', 'css'),
                "swagger-ui-bundle": config:cdn-url($dependencies, 'swagger-ui-dist', 'bundle'),
                "fore-css": config:cdn-url($dependencies, '@jinntec/fore', 'css'),
                "fore-bundle": config:cdn-url($dependencies, '@jinntec/fore', 'bundle'),
                "jinn-codemirror-bundle": config:cdn-url($dependencies, '@jinntec/jinn-codemirror', 'bundle')
            }
        else
            map {}
    let $baseConfigWithDeps := 
        if (map:size($dependencies) > 0) then
            map:merge(($baseConfig, map { 
                "dependencies": $dependencies,
                "cdn": $cdnUrls
            }))
        else
            $baseConfig
    let $mergedConfig :=
        fold-right($baseConfigWithDeps?profiles?*, $baseConfigWithDeps, function($profile, $config) {
            generator:call-prepare(generator:profile-path($profile), $config)
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
                    if ($settings?overwrite = $cpy:OVERWRITE_REINSTALL) then
                        $tempTarget
                    else
                        head(($installedPkg, $tempTarget)),
                "_update": exists($installedPkg) and $settings?overwrite != $cpy:OVERWRITE_REINSTALL,
                "_overwrite": $settings?overwrite,
                "_dry": $settings?dry,
                "template-suffix": "\.tpl"
            })
        )
    return
        map:merge(($config, map { 
            "skip": array { distinct-values(($config?skip?*, "setup.xql", if ($config?type = "bootstrap") then () else "config.json")) }
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
            for $extProfile in $extendedProfiles
            where not($extProfile = $profile)
            let $log := util:log("INFO", ("Loading extended profile: " || $extProfile))
            return
                generator:load-json(generator:profile-path($extProfile) || "/config.json", map {})
                => generator:extends($extProfile)
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
    if ($context?_dry or $context?type = "bootstrap") then
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