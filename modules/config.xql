xquery version "3.1";

module namespace config="https://tei-publisher.com/generator/xquery/config";

declare variable $config:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath := replace($rawPath, "^(?:xmldb:exist://(?:embedded-eXist-server|null)?)?(.+)$", "$1")
    return
        substring-before($modulePath, "/modules")
        
;

declare variable $config:temp_directory as xs:string := $config:app-root || '/temp';

declare variable $config:context-path := request:get-context-path() || substring-after($config:app-root, "/db");

(:~
 : Process styles array to replace hardcoded CDN URLs with templated versions.
 : 
 : @param $styles The styles array from config.json
 : @param $cdnUrls The pre-computed CDN URLs map
 : @param $dependencies The dependencies map from config/package.json (for package name lookup)
 : @return Processed styles array with CDN URLs replaced
 :)
declare function config:process-styles($styles as array(*)?, $cdnUrls as map(*)?, $dependencies as map(*)?) as array(*) {
    if (not(exists($styles)) or array:size($styles) = 0) then
        array {}
    else
        array {
            for $style in $styles?*
            return
                (: Check if this is a CDN URL for any package in our dependencies :)
                if (matches($style, 'cdn\.jsdelivr\.net/npm/')) then
                    (: Try to match against known packages :)
                    let $matched := 
                        if (exists($dependencies?jinks?cdn)) then
                            (: Find matching package and asset type :)
                            head((
                                for $package in map:keys($dependencies?jinks?cdn)
                                let $cdnConfig := $dependencies?jinks?cdn($package)
                                where $cdnConfig instance of map(*) and exists($cdnConfig?base)
                                let $basePattern := replace($cdnConfig?base, 'https?://cdn\.jsdelivr\.net/npm/', '')
                                where matches($style, $basePattern || '@[\d.]+')
                                return
                                    (: Determine asset type based on URL pattern :)
                                    if (exists($cdnConfig?css) and matches($style, '\.css')) then
                                        $package || '-css'
                                    else if (exists($cdnConfig?bundle) and matches($style, '\.js')) then
                                        $package || '-bundle'
                                    else
                                        (: Try any other asset types :)
                                        head((
                                            for $assetType in map:keys($cdnConfig)
                                            where $assetType != 'base' and matches($style, $cdnConfig($assetType))
                                            return
                                                $package || '-' || $assetType
                                        ))
                            ))
                        else
                            ()
                    return
                        if (exists($matched) and exists($cdnUrls($matched))) then
                            $cdnUrls($matched)
                        else
                            $style
                else
                    $style
        }
};

(:~
 : Get the effective version for a package, checking profile-specific overrides.
 : 
 : @param $dependencies The dependencies map from config/package.json
 : @param $package The package name
 : @param $activeProfiles Array of active profile names
 : @return The effective version (with prefix like ^ or ~) or empty sequence
 :)
declare function config:effective-version($dependencies as map(*)?, $package as xs:string, $activeProfiles as array(*)?) as xs:string? {
    if (not(exists($dependencies)) or map:size($dependencies) = 0) then
        ()
    else
        (: Check for profile-specific overrides (check in order, first match wins) :)
        let $overrideVersion := 
            if (exists($activeProfiles) and array:size($activeProfiles) > 0 and exists($dependencies?jinks?overrides)) then
                head((
                    for $profile in $activeProfiles?*
                    where exists($dependencies?jinks?overrides($profile))
                    let $profileOverrides := $dependencies?jinks?overrides($profile)
                    where $profileOverrides instance of map(*) and exists($profileOverrides($package))
                    return $profileOverrides($package)
                ))
            else
                ()
        return
            if (exists($overrideVersion)) then
                $overrideVersion
            else
                (: Use default version from dependencies :)
                ($dependencies?dependencies($package), $dependencies?devDependencies($package))[1]
};

(:~
 : Build a CDN URL from the dependencies registry, applying profile-specific overrides if present.
 : 
 : @param $dependencies The dependencies map from config/package.json
 : @param $package The package name
 : @param $asset The asset type (bundle, css, etc.)
 : @param $activeProfiles Optional array of active profile names for override checking
 : @return The complete CDN URL with version replaced
 :)
declare function config:cdn-url($dependencies as map(*)?, $package as xs:string, $asset as xs:string, $activeProfiles as array(*)?) as xs:string? {
    if (not(exists($dependencies)) or map:size($dependencies) = 0) then
        ()
    else
        let $versionWithPrefix := config:effective-version($dependencies, $package, $activeProfiles)
        let $version := 
            if (exists($versionWithPrefix)) then
                replace($versionWithPrefix, '^[\^~]', '')
            else
                ()
        let $cdnConfig := $dependencies?jinks?cdn($package)
        let $template := 
            if ($cdnConfig instance of map(*)) then
                $cdnConfig($asset)
            else
                ()
        return
            if (exists($version) and exists($template)) then
                let $base := $cdnConfig?base
                let $path := replace($template, '\{\{version\}\}', $version)
                return
                    $base || $path
            else
                ()
};

(:~
 : Build a CDN URL from the dependencies registry (backward compatibility - no overrides).
 : 
 : @param $dependencies The dependencies map from config/package.json
 : @param $package The package name
 : @param $asset The asset type (bundle, css, etc.)
 : @return The complete CDN URL with version replaced
 :)
declare function config:cdn-url($dependencies as map(*)?, $package as xs:string, $asset as xs:string) as xs:string? {
    config:cdn-url($dependencies, $package, $asset, ())
};