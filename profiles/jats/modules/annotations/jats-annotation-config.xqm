xquery version "3.1";

module namespace anno="http://teipublisher.com/api/annotations/config/jats";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

(:~
 : Name of the attribute to use as reference key for entities
 :)
declare variable $anno:reference-key := 'specific-use';

(:~
 : Return the entity reference key for the given node.
 :)
declare function anno:get-key($node as element()) as xs:string? {
    $node/@*[local-name(.) = $anno:reference-key]
};

(:~
 : Determine the entity type of the given node and return as string.
 :)
declare function anno:entity-type($node as element()) as xs:string? {
    typeswitch($node)
        case element(named-content) return
            let $content-type := $node/@content-type/string()
            return
                switch($content-type)
                    case "person" return "person"
                    case "place" return "place"
                    case "organization" return "organization"
                    case "term" return "term"
                    case "work" return "work"
                    default return ()
        case element(name) return
            (: name elements in contrib context are persons :)
            if ($node/ancestor::contrib) then
                "person"
            else
                ()
        case element(contrib) return
            (: contrib elements with contrib-type="person" are persons :)
            if ($node/@contrib-type = "person") then
                "person"
            else
                ()
        default return
            ()
};

(:~
 : Create JATS for the given type, properties and content of an annotation and return it.
 : This function is called when annotations are merged into the original JATS.
 :)
declare function anno:annotations($type as xs:string, $properties as map(*)?, $content as function(*)) {
    switch ($type)
        case "person" return
            <named-content content-type="person" specific-use="{$properties?specific-use}">{$content()}</named-content>
        case "place" return
            <named-content content-type="place" specific-use="{$properties?specific-use}">{$content()}</named-content>
        case "term" return
            <named-content content-type="term" specific-use="{$properties?specific-use}">{$content()}</named-content>
        case "organization" return
            <named-content content-type="organization" specific-use="{$properties?specific-use}">{$content()}</named-content>
        case "work" return
            <named-content content-type="work" specific-use="{$properties?specific-use}">{$content()}</named-content>
        case "hi" return
            <styled-content>
            { 
                if ($properties?rend) then attribute style-type { $properties?rend } else (),
                if ($properties?rendition) then attribute style { $properties?rendition } else (),
                $content()
            }
            </styled-content>
        case "abbreviation" return
            <abbrev>
            {
                if ($properties?expan) then attribute alt-text { $properties?expan } else (),
                $content()
            }
            </abbrev>
        case "sic" return
            (: JATS doesn't have sic/corr, use styled-content with style-type :)
            <styled-content style-type="sic">
                {$content()}
                {if ($properties?corr) then <named-content content-type="correction">{$properties?corr}</named-content> else ()}
            </styled-content>
        case "reg" return
            (: JATS doesn't have orig/reg, use styled-content :)
            <styled-content style-type="original">
                {$content()}
                {if ($properties?reg) then <named-content content-type="regularized">{$properties?reg}</named-content> else ()}
            </styled-content>
        case "note" return 
            let $parsed := parse-xml-fragment($properties?content) => anno:fix-namespaces()
            let $id := util:uuid()
            return (
                $content(),
                <xref ref-type="fn" rid="{$id}"/>,
                <fn id="{$id}">{$parsed}</fn>
            )
        case "date" return
            (: JATS doesn't have a general date element, use named-content with date info :)
            <named-content content-type="date">
            {
                if ($properties?when) then attribute iso-8601-date { $properties?when } else (),
                if ($properties?from) then attribute date-type { "from" } else (),
                if ($properties?to) then attribute date-type { "to" } else (),
                $content()
            }
            </named-content>
        case "app" return
            (: JATS doesn't have app/lem/rdg, use styled-content with alternatives :)
            <styled-content style-type="apparatus">
                <named-content content-type="lemma">{$content()}</named-content>
                {
                    for $prop in map:keys($properties)[starts-with(., 'rdg')]
                    let $n := replace($prop, "^.*\[(.*)\]$", "$1")
                    order by number($n)
                    return
                        <named-content content-type="reading" rid="{$properties('wit[' || $n || ']')}">{$properties($prop)}</named-content>
                }
            </styled-content>
        case "link" return
            <ext-link xlink:href="{$properties?target}">{$content()}</ext-link>
        case "pb" return
            (: JATS uses milestone-start for page breaks :)
            <milestone-start content-type="page" n="{$properties?n}">
            {
                if ($properties?facs != "") then
                    attribute facs { $properties?facs}
                else
                    ()
            }
            </milestone-start>
        case "edit" return
            $properties?content
        default return
            $content()
};

(:~
 : Search for existing occurrences of annotations of the given type and key
 : in the data collection.
 :
 : Used to display the occurrence count next to authority entries.
 :)
declare function anno:occurrences($type as xs:string, $key as xs:string) {
    switch ($type)
        case "person" return
            collection($config:data-default)//named-content[@content-type = "person"][@rid = $key]
        case "place" return
            collection($config:data-default)//named-content[@content-type = "place"][@rid = $key]
        case "term" return
            collection($config:data-default)//named-content[@content-type = "term"][@rid = $key]
        case "organization" return
            collection($config:data-default)//named-content[@content-type = "organization"][@rid = $key]
        case "work" return
            collection($config:data-default)//named-content[@content-type = "work"][@rid = $key]
        default return ()
};

declare %private function anno:fix-namespaces($nodes as item()*) {
    (: JATS doesn't use namespaces, so just return nodes as-is :)
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                anno:fix-namespaces($node/node())
            case element() return
                (: Remove any namespace declarations and return element in default namespace :)
                element { local-name($node) } {
                    $node/@*, for $child in $node/node() return anno:fix-namespaces($child)
                }
            default return
                $node
};

