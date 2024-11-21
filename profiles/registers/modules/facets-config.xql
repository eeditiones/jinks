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

(:
 : Display configuration for facets to be shown in the sidebar. The facets themselves
 : are configured in the index configuration, collection.xconf.
 :)
declare variable $facets-config:facets := [
    map {
        "dimension": "place",
        "heading": "serafin.facets.place",
        "max": 3,
        "hierarchical": false(),
        "source": "api/search/facets/place"
    },
    map {
        "dimension": "author",
        "heading": "serafin.facets.author",
        "max": 3,
        "hierarchical": false(),
        "source": "api/search/facets/author"
    },
    map {
        "dimension": "year",
        "heading": "serafin.facets.date",
        "max": 3,
        "hierarchical": false(),
        "source": "api/search/facets/year"
    },
    map {
        "dimension": "language",
        "heading": "facets.language",
        "max": 5,
        "hierarchical": false(),
        "output": function($label, $language) {
            util:log("INFO", ("Facet label: ", $label, "Language: ", $language)),
            if (matches($language, "^pl-?")) then
                switch($label)
                case "it" return "włoski"
                case "cz" return "czeski"
                case "la" return "łaciński"
                default return $label
            else
                switch($label)
                    case "it" return "Italian"
                    case "cz" return "Czech"
                    case "la" return "Latin"
                    default return $label
        }
    }
];