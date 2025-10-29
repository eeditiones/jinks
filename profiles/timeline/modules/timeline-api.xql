xquery version "3.1";

module namespace timeline="http://teipublisher.com/api/timeline";

declare namespace tei="http://www.tei-c.org/ns/1.0";

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

declare function timeline:correspondence-entries($request as map(*)) {
    let $currentDoc := config:get-document($request?parameters?id)
    let $docs := (
        $currentDoc,
        timeline:in-correspondence($currentDoc, 'previous-in-correspondence'),
        timeline:in-correspondence($currentDoc, 'next-in-correspondence')
    )
    return
        map:merge(
            for $entry in $docs
            group by $date := timeline:get-date($entry//tei:correspDesc/tei:correspAction[@type = 'sent']/tei:date)
            where exists($date)
            return
                map:entry(format-date($date, "[Y0001]-[M01]-[D01]"), map {
                    "count": count($entry),
                    "info":
                        <ul>
                        {
                            for $doc in $entry
                            return
                                <li>
                                    <a href="{util:document-name($doc)}">{$doc//tei:titleStmt/tei:title/string()}</a>
                                </li>
                        }
                        </ul>
                })
        )
};

declare function timeline:get-date($date)  {
    if($date/@when)
        then xs:date(timeline:normalize-date($date/@when/string()))
    else if($date/@notBefore)
        then xs:date(timeline:normalize-date($date/@notBefore/string()))
    else if($date/@notAfter)
        then xs:date(timeline:normalize-date($date/@notAfter/string()))
    else (
    )
};

declare function timeline:normalize-date($date as xs:string) {
    if (matches($date, "^\d{4}-\d{2}$")) then
        $date || "-01"
    else if (matches($date, "^\d{4}$")) then
        $date || "-01-01"
    else
        $date
};

declare function timeline:in-correspondence($currentDoc as document-node()?, $type as xs:string) {
    if (empty($currentDoc)) then
        ()
    else
        let $next := $currentDoc//tei:correspContext/tei:ref[@type = $type]/@target
        let $relPath := substring-after(util:collection-name($currentDoc), $config:data-root || "/") || "/" || $next
        let $nextDoc := config:get-document($relPath)
        return
            ($nextDoc, timeline:in-correspondence($nextDoc, $type))
};
