xquery version "3.1";

module namespace config="https://tei-publisher.com/generator/xquery/config";

declare variable $config:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath := replace($rawPath, "^(?:xmldb:exist://(?:embedded-eXist-server|null)?)?(.*)$", "$1")
    return
        substring-before($modulePath, "/modules")
        
;

declare variable $config:temp_directory as xs:string := $config:app-root || '/temp';

declare variable $config:context-path := request:get-context-path() || substring-after($config:app-root, "/db");