xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";

declare 
    %generator:after-write
function teip:change-landing($context as map(*), $target as xs:string) {
    if ($context?_update) then
        ()
    else (
        (: rename the landing page to index.html :)
        xmldb:rename($target || "/templates", "index.html", "browse.html"),
        xmldb:rename($target || "/templates", "landing.html", "index.html")
    )
};