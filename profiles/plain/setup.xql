xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";

declare 
    %generator:after-write
function teip:change-landing($context as map(*), $target as xs:string) {
    (: rename the landing page to index.html :)
    if (map:contains($context?defaults, "landing")) then
        xmldb:copy-resource($target || "/templates", $context?defaults?landing, $target || "/templates", "index.html")
    else
        ()
};