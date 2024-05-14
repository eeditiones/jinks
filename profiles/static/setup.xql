xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace static="http://tei-publisher.com/jinks/static" at "../../modules/static.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";

declare 
    %generator:write
function teip:setup($context as map(*)) {
    cpy:copy-resource($context, $context?publisher || "/data/test/F-rom.xml", "data/F-rom.xml"),
    cpy:copy-collection($context)
};

declare 
    %generator:after-write
function teip:after-write($collection as xs:string, $context as map(*)) {
    static:paginate($context, "F-rom.xml", "static/page.html", function($context as map(*), $n as xs:int) {
        "site/F-rom.xml/" || $n
    })
};