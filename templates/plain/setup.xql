xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

declare namespace generator="http://tei-publisher.com/library/generator";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";

declare 
    %generator:write
function teip:setup($context as map(*)) {
    cpy:copy-collection($context)
};