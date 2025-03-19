xquery version "3.1";

module namespace tu="http://e-editiones.org/jinks/templates/util";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";

(:~
 : Load the content of a file or document. Handles both binary and XML resources.
 : 
 : @param $path the path to the resource to load
 : @return the content of the resource - either binary data or parsed XML
 :)
declare function tu:scan-collection($relPath as xs:string) {
    let $path := $config:app-root || "/" || $relPath
    return 
        if (xmldb:collection-available($path)) then (
            for $file in xmldb:get-child-resources($path)
            return
                $relPath || "/" || $file,
            for $dir in xmldb:get-child-collections($path)
            return
                tu:scan-collection($relPath || "/" || $dir)
        ) else (
            ()
        )
};
