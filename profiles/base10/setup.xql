xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../paths.xql";

declare 
    %generator:prepare
function teip:prepare($context as map(*)) {
    (: Add custom ODD to list of ODDs, so generated modules are updated accordingly :)
    if (map:get($context, "custom-odd")) then
        map:merge((
            $context,
            map:entry("odds", array { distinct-values(($context?odds, $context?custom-odd)) })
        ))
    else
        $context
};

declare 
    %generator:write
function teip:setup($context as map(*)) {
    util:log("INFO", "base10: Start copying files ..."),
    cpy:copy-collection($context),
    util:log("INFO", "base10: copying files done."),
    teip:custom-odd-install($context)
};

declare 
    %generator:after-write
function teip:change-landing($context as map(*), $target as xs:string) {
    (: rename the landing page to index.html :)
    if (map:contains($context?defaults, "landing") and
        $context?defaults?landing != "index.html") then
        xmldb:copy-resource($target || "/templates", $context?defaults?landing, $target || "/templates", "index.html")
    else
        ()
};

declare %private function teip:custom-odd-install($context as map(*)) {
    if (map:get($context, "custom-odd")) then
        let $_ := util:log("INFO", "base10: Installing custom ODD " || $context?custom-odd)
        let $path := path:resolve-path($context?target || "/resources/odd", $context?custom-odd)
        return
            if (doc-available($path)) then
                ()
            else
                let $template := cpy:resource-as-string($context, "resources/odd/template.odd")
                let $expanded := cpy:expand-template("template.odd", $template?content, $context)
                let $_ := (
                    xmldb:store(path:parent($path), path:basename($path), $expanded),
                    sm:chown(xs:anyURI($path), $context?pkg?user?name),
                    sm:chgrp(xs:anyURI($path), $context?pkg?user?group),
                    sm:chmod(xs:anyURI($path), $context?pkg?permissions)
                )
                return
                    map {
                        "type": "create",
                        "path": $path
                    }
    else
        ()
};