xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../paths.xql";

declare 
    %generator:after-write
function teip:installConfig($context as map(*), $target as xs:string) {
    let $targetPath := path:resolve-path($target, "config.json")
    let $sourcePath := path:resolve-path($target, "config.tps.json")
    let $template := cpy:resource-as-string($context, $sourcePath)
    let $expanded := cpy:expand-template($sourcePath, $template?content, $context)
    let $_ := util:log("INFO", "Expanding " || $sourcePath || " to " || $targetPath)
    let $_ := (
        xmldb:store($target, "config.json", $expanded),
        xmldb:remove($target, "config.tps.json"),
        xmldb:remove($target, "context.json"),
        xmldb:remove($target, ".jinks.json")
    )
    return
        map {
            "type": "create",
            "path": $targetPath
        }
};