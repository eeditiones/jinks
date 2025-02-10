xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../paths.xql";

declare 
    %generator:write
function teip:setup($context as map(*)) {
    util:log("INFO", "base10: Start copying files ..."),
    cpy:copy-collection($context),
    util:log("INFO", "base10: copying files done.")
};

declare 
    %generator:after-write
function teip:change-landing($context as map(*), $target as xs:string) {
    (: rename the landing page to index.html :)
    if (map:contains($context?defaults, "landing") and
        $context?defaults?landing != "index.html") then
        xmldb:copy-resource($target || "/templates", $context?defaults?landing, $target || "/templates", "index.html")
    else
        ()
};