xquery version "3.1";

module namespace tu="http://e-editiones.org/jinks/templates/util";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xqm";

declare function tu:scan-collection($relPath as xs:string) {
    tu:scan-collection($relPath, ())
};

(:~
 : Load the content of a file or document. Handles both binary and XML resources.
 : 
 : @param $path the path to the resource to load
 : @param $pattern an optional regular expression to filter the files
 : @return the content of the resource - either binary data or parsed XML
 :)
declare function tu:scan-collection($relPath as xs:string, $pattern as xs:string?) {
    let $path := $config:app-root || "/" || $relPath
    return 
        if (xmldb:collection-available($path)) then (
            for $file in xmldb:get-child-resources($path)
            where not($pattern) or matches($file, $pattern)
            return
                $relPath || "/" || $file,
            for $dir in xmldb:get-child-collections($path)
            return
                tu:scan-collection($relPath || "/" || $dir, $pattern)
        ) else (
            ()
        )
};
