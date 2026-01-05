xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";

declare namespace generator="http://tei-publisher.com/library/generator";

declare 
    %generator:write
function teip:setup($context as map(*)) {
    path:mkcol($context, $context?target),
    util:log("INFO", "new-profile: Start copying files ..."),
    cpy:copy-template($context, "config.tpl.json", "config.json"),
    cpy:copy-template($context, "expath-pkg.tpl.xml", "expath-pkg.xml"),
    cpy:copy-template($context, "repo.tpl.xml", "repo.xml"),
    cpy:copy-template($context, "build.tpl.xml", "build.xml"),
    util:log("INFO", "new-profile: copying files done.")
};