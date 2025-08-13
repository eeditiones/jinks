xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../paths.xql";

(:~
 : After write hook: generates a components.css to be imported into webcomponents.
 :
 : @param $context the context map
 : @param $target the target path
 :)
declare 
    %generator:after-write
function teip:after-write($context as map(*), $target as xs:string) {
    if ($context?production) then (
        cpy:concat(
            map:merge(($context, map:entry("source", $target))), 
            (
                concat("palette-", ($context?theme?colors?palette, "neutral")[1], ".css"),
                "resources/css/jinks-variables.css",
                "resources/css/pico-ext.css",
                "resources/css/base.css",
                "resources/fonts/font.css",
                "resources/css/layouts.css",
                "resources/css/controls.css",
                "resources/css/menu.css",
                "resources/css/documents.css",
                "resources/css/toc.css",
                "resources/css/jinks-theme.css"
            ),
            "resources/css/jinks-theme-bundle.css"
        )
    ) else ()
    ,
    cpy:concat(
        map:merge(($context, map:entry("source", $target))), 
        (
            "resources/css/pico-components.css",
            "resources/css/jinks-variables.css",
            "resources/css/controls.css",
            "resources/css/jinks-components.css"
        ),
        "resources/css/components.css"
    )
};


