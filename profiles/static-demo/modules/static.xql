xquery version "3.1";

import module namespace static="http://tei-publisher.com/jinks/static" at "xmldb:exist:///db/apps/jinks/modules/static.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
let $context := static:prepare($jsonConfig)
let $people := static:load($context?base-uri || "/api/people/all")
let $places := static:load($context?base-uri || "/api/places/all")
return (
    static:generate-from-config($context),
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
    let $log := util:log("INFO", ("Processing person: ", $person?id))
    return
        static:paginate(
            map:merge(($context, map:entry("person", $person))),
            [
                map {
                    "odd": "serafin.odd",
                    "path": "registers/persons.xml",
                    "xpath": "/id('" || $person?id || "')",
                    "view": "single"
                }
            ],
            "static/templates/person.html",
            function($context as map(*), $n as xs:int) {
                "people/" || $person?id
            }
        ),
    static:redirect($context, "people", "a/index.html")
)