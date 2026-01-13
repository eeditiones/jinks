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
 : Build a CDN URL from the dependencies registry.
 : 
 : @param $dependencies The dependencies map from config/package.json
 : @param $package The package name
 : @param $asset The asset type (bundle, css, etc.)
 : @return The complete CDN URL with version replaced
 :)
declare function config:cdn-url($dependencies as map(*)?, $package as xs:string, $asset as xs:string) as xs:string? {
    if (not(exists($dependencies)) or map:size($dependencies) = 0) then
        ()
    else
        let $versionWithPrefix := ($dependencies?dependencies($package), $dependencies?devDependencies($package))[1]
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