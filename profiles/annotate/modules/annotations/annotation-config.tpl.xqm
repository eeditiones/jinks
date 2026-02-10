xquery version "3.1";

module namespace anno="http://teipublisher.com/api/annotations/config";

import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

[% for $doctype in map:keys($context?features?annotate?configs) %]
[% let $config = $context?features?annotate?configs($doctype) %]
import module namespace [[ $doctype ]]="[[ $config?id ]]" at "[[ $config?path ]]";
[% endlet %]
[% endfor %]

(:~
 : Name of the attribute to use as reference key for entities
 :)
declare variable $anno:reference-key := 'key';

(:~
 : Return the entity reference key for the given node.
 :)
declare function anno:get-key($node as element()) as xs:string? {
    let $doctype := config:document-type($node)
    return
        switch($doctype)
            [% for $doctype in map:keys($context?features?annotate?configs) %]
            case "[[ $doctype ]]" return
                [[ $doctype ]]:get-key($node)
            [% endfor %]
            default return
                error($errors:NOT_FOUND, "Unsupported doctype: " || $doctype)
};

(:~
 : Create XML for the given type, properties and content of an annotation and return it.
 : This function is called when annotations are merged into the original XML.
 :)
declare function anno:annotations($doctype as xs:string, $type as xs:string, $properties as map(*)?, $content as function(*)) {
    switch ($doctype)
        [% for $doctype in map:keys($context?features?annotate?configs) %]
        case "[[ $doctype ]]" return
            [[ $doctype ]]:annotations($type, $properties, $content)
        [% endfor %]
        default return
            error($errors:NOT_FOUND, "Unsupported doctype: " || $doctype)
};

(:~
 : Determine the entity type of the given node and return as string.
 :)
declare function anno:entity-type($node as element()) as xs:string? {
    head((
    [[ string-join(map:keys($context?features?annotate?configs) ! (. || ':entity-type($node)'), ', ') ]]
    ))
};

declare function anno:occurrences($type as xs:string, $key as xs:string) {
    [[ string-join(map:keys($context?features?annotate?configs) ! (. || ':occurrences($type, $key)'), ', ') ]]
};