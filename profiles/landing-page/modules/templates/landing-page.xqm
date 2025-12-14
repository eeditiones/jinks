xquery version "3.1";

module namespace landing="http://teipublisher.com/ns/templates/landing-page";

import module namespace page="http://teipublisher.com/ns/templates/page" at "page.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function landing:section($context as map(*), $name as xs:string, $root as node()) {
    let $lang := page:parameter($context, 'lang')
    let $nodes := head(($root//tei:div[@type=$name][@xml:lang=$lang], $root//tei:div[@type=$name]))
    return
        page:transform($nodes, map { "browse-url": $context?defaults?browse }, "landing.odd")
};