xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../paths.xql";

declare 
    %generator:after-write
function teip:after-write($context as map(*), $target as xs:string) {
    cpy:concat(
        map:merge(($context, map:entry("source", $target))), 
        ("resources/css/pico-components.css", "resources/css/variables.css"), 
        "resources/css/components.css"
    )
};