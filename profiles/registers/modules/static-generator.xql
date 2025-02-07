xquery version "3.1";

module namespace sg="http://tei-publisher.com/static/generate";

import module namespace static="http://tei-publisher.com/jinks/static" at "xmldb:exist:///db/apps/jinks/modules/static.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare function sg:generate-static($request as map(*)) {
    array {
        let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
        let $context := static:prepare($jsonConfig)
        return (
            static:generate-from-config($context),
            sg:people($context),
            sg:places($context)
        )
    }
};

declare %private function sg:people($context as map(*)) {
    let $people := static:load($context?base-uri || "/api/people/all")
    return (
        let $grouped :=
            for $person in $people?*
            group by $letter := substring($person?name, 1, 1) => upper-case()
            order by $letter collation "?lang=pl"
            return map {
                "page": $letter,
                "data": array { $person }
            }
        return
            static:split($context, $grouped, "static/templates/people.html", function($context as map(*), $page) {
                "people/" || encode-for-uri($page)
            }),
        for $person in $people?*
        let $_ := util:log("INFO", ("Processing person: ", $person?id))
        return
            static:paginate(
                map:merge(($context, map:entry("person", $person))),
                [
                    map {
                        "odd": "serafin.odd",
                        "path": "registers/persons.xml",
                        "xpath": "/id('" || $person?id || "')",
                        "view": "single",
                        "user.context-path": $context?context-path,
                        "user.static": true(),
                        "user.mode": "register-details"
                    }
                ],
                "static/templates/person.html",
                function($context as map(*), $n as xs:int) {
                    "people/" || $person?id
                }
            ),
        static:redirect($context, "people", "A/index.html")
    )
};

declare %private function sg:places($context as map(*)) {
    let $places := static:load($context?base-uri || "/api/places/all")
    return (
        let $grouped :=
            for $place in $places?*
            group by $letter := substring($place?label, 1, 1) => upper-case()
            order by $letter collation "?lang=pl"
            return map {
                "page": $letter,
                "data": array { $place }
            }
        return
            static:split(
                map:merge(($context, map:entry("geodata", $places))), 
                $grouped, 
                "static/templates/places.html", 
                function($context as map(*), $page) {
                    "places/" || encode-for-uri($page)
                }
            ),
        for $place in $places?*
        let $_ := util:log("INFO", ("Processing place: ", $place?id))
        return
            static:paginate(
                map:merge(($context, map:entry("place", $place))),
                [
                    map {
                        "odd": "serafin.odd",
                        "path": "registers/places.xml",
                        "xpath": "/id('" || $place?id || "')",
                        "view": "single",
                        "user.context-path": $context?context-path,
                        "user.static": true(),
                        "user.mode": "register-details"
                    }
                ],
                "static/templates/place.html",
                function($context as map(*), $n as xs:int) {
                    "places/" || $place?id
                }
            ),
        static:redirect($context, "places", "A/index.html")
    )
};