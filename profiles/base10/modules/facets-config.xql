module namespace facets-config="http://teipublisher.com/api/facets-config";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function facets-config:get-name($id as xs:string, $type as xs:string) as xs:string {
    let $entity := collection($config:register-root)/id($id)
    return head((
            switch ($type)
                case 'place' return head(($entity//tei:placeName[@type = "main"], $entity//tei:placeName))
                case 'actor' return head(($entity//(tei:persName | tei:orgName)[@type = "main"], $entity//tei:placeName))
                default return "ERR",
             "Unresolvable entity " || $id || " of type " || $type)
        )
};

declare %public variable $facets-config:facets as array(*) := [
    map {
        "dimension": "place",
        "heading": "facets.place",
        "max": 5,
        "hierarchical": false(),
        "output": facets-config:get-name(?, 'place')
    },
    map {
        "dimension": "actor",
        "heading": "facets.actor",
        "max": 5,
        "hierarchical": false(),
        "output": facets-config:get-name(?, 'actor')
    }
];
