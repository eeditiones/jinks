xquery version "3.1";

module namespace anno="http://teipublisher.com/api/annotations/config/tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

[% let $key = $context?features?annotate?configs?tei?key %]

(:~
 : Name of the attribute to use as reference key for entities
 :)
declare variable $anno:reference-key := '[[ $key ]]';

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
        case element(tei:persName) | element(tei:author) return
            "person"
        case element(tei:placeName) | element(tei:pubPlace) return
            "place"
        case element(tei:term) return
            "term"
        case element(tei:orgName) return
            "organization"
        case element(tei:bibl) return
            "work"
        default return
            ()
};

(:~
 : Create TEI for the given type, properties and content of an annotation and return it.
 : This function is called when annotations are merged into the original TEI.
 :)
declare function anno:annotations($type as xs:string, $properties as map(*)?, $content as function(*)) {
    switch ($type)
        case "person" return
            <persName xmlns="http://www.tei-c.org/ns/1.0" [[ $key ]]="{$properties?[[ $key]]}">{$content()}</persName>
        case "place" return
            <placeName xmlns="http://www.tei-c.org/ns/1.0" [[ $key ]]="{$properties?[[ $key ]]}">{$content()}</placeName>
        case "term" return
            <term xmlns="http://www.tei-c.org/ns/1.0" [[ $key ]]="{$properties?[[ $key ]]}">{$content()}</term>
        case "organization" return
            <orgName xmlns="http://www.tei-c.org/ns/1.0" [[ $key ]]="{$properties?[[ $key ]]}">{$content()}</orgName>
        case "work" return
            <bibl xmlns="http://www.tei-c.org/ns/1.0" [[ $key ]]="{$properties?[[ $key ]]}" type="work">{$content()}</bibl>
        case "hi" return
            <hi xmlns="http://www.tei-c.org/ns/1.0">
            { 
                if ($properties?rend) then attribute rend { $properties?rend } else (),
                if ($properties?rendition) then attribute rendition { $properties?rendition } else (),
                $content()
            }
            </hi>
        case "abbreviation" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><abbr>{$content()}</abbr><expan>{$properties?expan}</expan></choice>
        case "sic" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><sic>{$content()}</sic><corr>{$properties?corr}</corr></choice>
        case "reg" return
            <choice xmlns="http://www.tei-c.org/ns/1.0"><orig>{$content()}</orig><reg>{$properties?reg}</reg></choice>
        case "note" return 
            let $parsed := parse-xml-fragment($properties?content) => anno:fix-namespaces()
            let $id := util:uuid()
            return (
                $content(),
                <anchor xmlns="http://www.tei-c.org/ns/1.0" xml:id="{$id}" type="note"/>,
                (: because the note has a @target, it will be extracted into standOff/listAnnotation later :)
                <note xmlns="http://www.tei-c.org/ns/1.0" target="#{$id}">{$parsed}</note>
            )
        case "date" return
            <date xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $prop in map:keys($properties)[. = ('when', 'from', 'to')]
                return
                    attribute { $prop } { $properties($prop) },
                $content()
            }
            </date>
        case "app" return
            <app xmlns="http://www.tei-c.org/ns/1.0">
                <lem>{$content()}</lem>
                {
                    for $prop in map:keys($properties)[starts-with(., 'rdg')]
                    let $n := replace($prop, "^.*\[(.*)\]$", "$1")
                    order by number($n)
                    return
                        <rdg wit="{$properties('wit[' || $n || ']')}">{$properties($prop)}</rdg>
                }
            </app>
        case "link" return
            <ref xmlns="http://www.tei-c.org/ns/1.0" target="{$properties?target}">{$content()}</ref>
        case "pb" return
            <pb xmlns="http://www.tei-c.org/ns/1.0" n="{$properties?n}">
            {
                if ($properties?facs != "") then
                    attribute facs { $properties?facs}
                else
                    ()
            }
            </pb>
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
            collection($config:data-default)//tei:persName[@[[ $key ]] = $key]
        case "place" return
            collection($config:data-default)//tei:placeName[@[[ $key ]] = $key]
        case "term" return
            collection($config:data-default)//tei:term[@[[ $key ]] = $key]
        case "organization" return
            collection($config:data-default)//tei:orgName[@[[ $key ]] = $key]
        case "work" return
            collection($config:data-default)//tei:bibl[@[[ $key ]] = $key]
        default return ()
};

(:~
 : Add a revisionDesc to the TEI header and move notes with a @target into standOff/listAnnotation.
 :)
declare function anno:extend-header($nodes as node()*, $log as map(*)?) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document {
                    anno:extend-header($node/node(), $log)
                }
            case element(tei:TEI) return
                element { node-name($node) } {
                    $node/@*,
                    anno:extend-header($node/node(), $log),
                    if (not($node/tei:standOff)) then
                        <standOff xmlns="http://www.tei-c.org/ns/1.0">
                            <listAnnotation>
                                {
                                    for $note in root($node)/tei:text//tei:note[@target]
                                    return
                                        $note
                                }
                            </listAnnotation>
                        </standOff>
                    else
                        ()
                }
            case element(tei:standOff) return
                element { node-name($node) } {
                    $node/@*,
                    anno:extend-header($node/node(), $log),
                    if (not($node/tei:listAnnotation)) then
                        <listAnnotation xmlns="http://www.tei-c.org/ns/1.0">
                        {
                            for $note in root($node)/tei:text//tei:note[@target]
                            return
                                $note
                        }
                        </listAnnotation>
                    else
                        ()
                }
            case element(tei:listAnnotation) return
                element { node-name($node) } {
                    $node/@*,
                    anno:extend-header($node/node(), $log),
                    for $note in root($node)/tei:text//tei:note[@target]
                    return
                        $note
                }
            case element(tei:note) return
                if ($node/ancestor::tei:text and $node/@target) then
                    ()
                else
                    $node
            case element(tei:teiHeader) return
                element { node-name($node) } {
                    $node/@*,
                    if (not($node/tei:revisionDesc)) then
                        if ($log?message != "") then
                            <revisionDesc xmlns="http://www.tei-c.org/ns/1.0">
                                <listChange>
                                    <change when="{current-dateTime()}" who="{$log?user}" status="{$log?status}">{$log?message}</change>
                                </listChange>
                            </revisionDesc>
                        else
                            ()
                    else
                        (),
                    anno:extend-header($node/node(), $log)
                }
            case element(tei:revisionDesc) return
                if (not($node/tei:listChange)) then
                    element { node-name($node) } {
                        $node/@*,
                        $node/node(),
                        if ($log?message != "") then
                            <listChange xmlns="http://www.tei-c.org/ns/1.0">
                                <change when="{current-dateTime()}" who="{$log?user}" status="{$log?status}">{$log?message}</change>
                            </listChange>
                        else
                            ()
                    }
                else
                    element { node-name($node) } {
                        $node/@*,
                        anno:extend-header($node/node(), $log)
                    }
            case element(tei:listChange) return
                element { node-name($node) } {
                    $node/@*,
                    $node/node(),
                    if ($log?message != "") then
                        <change xmlns="http://www.tei-c.org/ns/1.0" when="{current-dateTime()}" who="{$log?user}" status="{$log?status}">{$log?message}</change>
                    else
                        ()
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    anno:extend-header($node/node(), $log)
                }
            default return
                $node
};

declare %private function anno:fix-namespaces($nodes as item()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                anno:fix-namespaces($node/node())
            case element() return
                element { QName("http://www.tei-c.org/ns/1.0", local-name($node)) } {
                    $node/@*, for $child in $node/node() return anno:fix-namespaces($child)
                }
            default return
                $node
};
[% endlet %]