xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";

declare namespace generator="http://tei-publisher.com/library/generator";

declare 
    %generator:write
function teip:setup($context as map(*)) {
    util:log("INFO", "base10: Start copying files ..."),
    cpy:copy-collection($context),
    util:log("INFO", "base10: copying files done.")
};

declare 
    %generator:after-write
function teip:after-write($context as map(*), $target as xs:string) {
    teip:custom-odd-install($context, $target)
};

(:~
 : Checks if all referenced ODDs are available. Creates an empty ODD from template if not.
 :
 : @param $context the context map
 : @param $target the target path
 :)
declare %private function teip:custom-odd-install($context as map(*), $target as xs:string) {
    if (map:contains($context, "odds")) then
        for $odd in $context?odds?*
        let $path := path:resolve-path($target || "/resources/odd", $odd)
        where not(doc-available($path))
        let $_ := util:log("INFO", "base10: Installing custom ODD " || $path)
        let $sourcePath := path:resolve-path($target || "/resources/odd", "template.odd.xml")
        let $_ := cpy:copy-template($context, $sourcePath, $path)
        return
            map {
                "type": "create",
                "path": $path
            }
    else
        ()
};