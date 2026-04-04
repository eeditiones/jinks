xquery version "3.1";

module namespace site="https://exist-db.org/jinks/exist-site/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";

declare namespace generator="http://tei-publisher.com/library/generator";

declare
    %generator:write
function site:setup($context as map(*)) {
    cpy:copy-collection($context)
};
