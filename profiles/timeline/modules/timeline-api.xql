xquery version "3.1";

module namespace timeline="http://teipublisher.com/api/timeline";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare function timeline:timeline($request as map(*)) {
    let $entries := session:get-attribute($config:session-prefix || '.hits')
    let $datedEntries := filter($entries, function($entry) {
            try {
                let $date := ft:field($entry, "date", "xs:date")
                return
                    exists($date) and year-from-date($date) != 1000
            } catch * {
                false()
            }
        })
    return
        map:merge(
            for $entry in $datedEntries
            group by $date := ft:field($entry, "date", "xs:date")
            return
                map:entry(format-date($date, "[Y0001]-[M01]-[D01]"), map {
                    "count": count($entry),
                    "info": ''
                })
        )
};