xquery version "3.1";

module namespace reg="https://teipublisher.com/generator/profiles/registers";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";

declare 
    %generator:write
function reg:setup($context as map(*)) {
    cpy:copy-collection($context)
};