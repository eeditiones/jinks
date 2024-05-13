xquery version "3.1";

module namespace anno="https://teipublisher.com/generator/profiles/annotate";

import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../modules/paths.xql";

declare 
    %generator:write
function anno:setup($context as map(*)) {
    paths:mkcol($context, "resources/scripts/annotations"),
    cpy:copy-collection($context, $context?publisher || "/resources/scripts/annotations", "resources/scripts/annotations"),
    cpy:copy-resource($context, $context?publisher || "/resources/css/annotate.css", "resources/css/annotate.css"),
    cpy:copy-collection($context)
};