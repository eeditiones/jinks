xquery version "3.1";

module namespace anno="http://teipublisher.com/api/annotations/config/tei";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

[% let $key = $context?features?annotate?configs?tei?key %]

(:~
 : Name of the attribute to use as reference key for entities - a single, global name
 : (config.json's features.annotate.configs.tei.key, "key" by default) used server-side for
 : occurrence lookups below. This is a DIFFERENT mechanism from the client-side keyMap in the same
 : config: keyMap tells the editor's click-to-view popup (pb-view-annotate.js) which attribute
 : holds an entity's *id* per type, and can point at @ref once a `fields` mapping is configured;
 : $anno:reference-key/anno:get-key are unrelated to that and always mean literally @key.
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
 :
 : person/place/term/organization/work all copy EVERY entry of $properties through as an
 : attribute generically (not just the reference/key field, [[ $key ]]) - this is what makes a
 : connector's `fields` mapping (see tei-publisher-components' Registry.buildProperties) usable at
 : all. A form field with no value for the current selection is never in $properties to begin
 : with (see annotations.js applyFieldValues/authoritySelected), so this never emits an attribute
 : with an empty value.
 :)
declare function anno:annotations($type as xs:string, $properties as map(*)?, $content as function(*)) {
    switch ($type)
        case "person" return
            <persName xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $prop in map:keys($properties) return attribute { $prop } { $properties($prop) },
                $content()
            }
            </persName>
        case "place" return
            <placeName xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $prop in map:keys($properties) return attribute { $prop } { $properties($prop) },
                $content()
            }
            </placeName>
        case "term" return
            <term xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $prop in map:keys($properties) return attribute { $prop } { $properties($prop) },
                $content()
            }
            </term>
        case "organization" return
            <orgName xmlns="http://www.tei-c.org/ns/1.0">
            {
                for $prop in map:keys($properties) return attribute { $prop } { $properties($prop) },
                $content()
            }
            </orgName>
        case "work" return
            <bibl xmlns="http://www.tei-c.org/ns/1.0" type="work">
            {
                for $prop in map:keys($properties) return attribute { $prop } { $properties($prop) },
                $content()
            }
            </bibl>
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
 : Used to display the occurrence count next to authority entries. $key here is
 : whatever id pb-authority-lookup.js sent (a candidate's real id, e.g. "kbga-actors-403"
 : or "gnd-137224435" - see _occurrences() in pb-authority-lookup.js), not necessarily
 : the value of @[[ $key ]]/$anno:reference-key: once a type is field-mapped (see
 : annotate-tei.html's `fields=` attributes), the id lands in @ref instead, and @[[ $key ]]
 : holds the (slugified, non-unique) label. Matching @ref as well as @[[ $key ]] covers
 : both an unmapped annotation (id in @[[ $key ]]) and a field-mapped one (id in @ref)
 : without needing this function to know which convention a given annotation used.
 :)
declare function anno:occurrences($type as xs:string, $key as xs:string) {
    switch ($type)
        case "person" return
            collection($config:data-default)//tei:persName[@[[ $key ]] = $key or @ref = $key]
        case "place" return
            collection($config:data-default)//tei:placeName[@[[ $key ]] = $key or @ref = $key]
        case "term" return
            collection($config:data-default)//tei:term[@[[ $key ]] = $key or @ref = $key]
        case "organization" return
            collection($config:data-default)//tei:orgName[@[[ $key ]] = $key or @ref = $key]
        case "work" return
            collection($config:data-default)//tei:bibl[@[[ $key ]] = $key or @ref = $key]
        default return ()
};

(:~
 : Coerce a log field (message/user/status) to a plain string. Defends against a
 : client sending an empty JSON object (e.g. {}) where a string was expected.
 :
 : NOTE: do not write a backtick immediately followed by an opening curly brace
 : anywhere in this file, even inside a comment - Jinks's templates.xqm wraps the
 : whole .tpl.xqm source in an eXist string constructor and treats that exact
 : sequence as the start of a real interpolation, corrupting template expansion
 : (confirmed the hard way: err:XPST0003 "unexpected token: ." from cpy:template).
 :
 : This happened in practice when an fx-property's expr yielded a raw attribute
 : node instead of an atomized string - JSON.stringify() collapses such a node to
 : "{}" client-side, which parse-json() turns back into an empty map server-side.
 : Fixed at the client too (annotate.html's pb-commit dispatch now calls string()
 : on every property), but this stays as defense in depth so a malformed request
 : body can never 500 here.
 :)
declare function anno:sanitize-log-value($value as item()*) as xs:string {
    if (empty($value) or $value instance of function(*)) then
        ""
    else
        string($value)
};

(:~
 : Add a revisionDesc to the TEI header and move notes with a @target into standOff/listAnnotation.
 :)
declare function anno:extend-header($nodes as node()*, $log as map(*)?) {
    let $log :=
        if (empty($log)) then
            $log
        else
            map:merge((
                $log,
                map {
                    "message": anno:sanitize-log-value($log?message),
                    "user": anno:sanitize-log-value($log?user),
                    "status": anno:sanitize-log-value($log?status)
                }
            ))
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
                    if (not($node/tei:standOff) and root($node)/tei:text//tei:note[@target]) then
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
