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
function teip:after-write($context as map(*), $target as xs:string) {
    teip:change-landing($context, $target),
    teip:custom-odd-install($context, $target)
};

declare %private function teip:change-landing($context as map(*), $target as xs:string) {
    (: rename the landing page to index.html :)
    if (map:contains($context?defaults, "landing") and
        $context?defaults?landing != "index.html") then
        xmldb:copy-resource($target || "/templates", $context?defaults?landing, $target || "/templates", "index.html")
    else
        ()
};

declare %private function teip:custom-odd-install($context as map(*), $target as xs:string) {
    if (map:contains($context, "odds")) then
        for $odd in $context?odds?*
        let $path := path:resolve-path($target || "/resources/odd", $odd)
        where not(doc-available($path))
        let $_ := util:log("INFO", "base10: Installing custom ODD " || $path)
        let $sourcePath := path:resolve-path($target || "/resources/odd", "template.odd")
        let $_ := cpy:copy-template($context, $sourcePath, $path)
        (: let $template := cpy:resource-as-string($target, "resources/odd/template.odd")
        let $expanded := cpy:expand-template("template.odd", $template?content, $context)
        let $_ := (
            xmldb:store(path:parent($path), path:basename($path), $expanded),
            sm:chown(xs:anyURI($path), $context?pkg?user?name),
            sm:chgrp(xs:anyURI($path), $context?pkg?user?group),
            sm:chmod(xs:anyURI($path), $context?pkg?permissions)
        ) :)
        return
            map {
                "type": "create",
                "path": $path
            }
    else
        ()
};