xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";

declare namespace generator="http://tei-publisher.com/library/generator";

(:~
 : After write hook: generates a components.css to be imported into webcomponents.
 :
 : @param $context the context map
 : @param $target the target path
 :)
declare
    %generator:after-write
function teip:after-write($context as map(*), $target as xs:string) {
    let $palette := concat("resources/css/palette-", ($context?theme?colors?palette, "neutral")[1], ".css")
    let $context-with-target := map:merge(($context, map:entry("source", $target)))

    let $theme-bundle :=
        if ($context?production) then (
            cpy:concat(
                $context-with-target, 
                (
                    $palette,
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
                "resources/css/jinks-theme.css" (: overwrite style :)
            )
        ) else ()

    let $components-bundle :=
        cpy:concat(
            $context-with-target,
            (
                $palette,
                "resources/css/pico-components.css",
                "resources/css/jinks-variables.css",
                "resources/css/pico-ext.css",
                "resources/css/controls.css",
                "resources/css/jinks-components.css"
            ),
            "resources/css/components.css"
        )

    return ($theme-bundle, $components-bundle)
};


