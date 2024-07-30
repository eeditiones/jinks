xquery version "3.1";

module namespace rview="http://teipublisher.com/api/registers/view";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";
import module namespace vapi="http://teipublisher.com/api/view" at "lib/api/view.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function rview:sort($people as array(*)*, $dir as xs:string) {
    let $sorted :=
        sort($people, "?lang=de-DE", function($entry) {
            $entry?1
        })
    return
        if ($dir = "asc") then
            $sorted
        else
            reverse($sorted)
};

declare function rview:people-all($request as map(*)){
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $sortDir := ($request?parameters?dir, 'asc')[1]
    let $limit := $request?parameters?limit
    let $people :=
            if ($search and $search != '') then
                collection($config:register-root)//tei:person[ft:query(., 'name:(' || $search || '*)')]
            else
                collection($config:register-root)//tei:person
    let $byKey := for-each($people, function($person as element()) {
        let $label := ($person//tei:persName[@type='sort'], $person//tei:persName)[1]
        return
            [lower-case($label), $label, $person]
    })
    let $sorted := rview:sort($byKey, $sortDir)
    let $letter := 
        if (count($people) < $limit) then 
            "all"
        else if ($letterParam = '') then
            substring($sorted[1]?1, 1, 1) => upper-case()
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'all') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with($entry?1, lower-case($letter))
            })
    return
        map {
            "items": rview:output-person-all($byLetter, $letter, $search),
            "categories":
                if (count($people) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with($entry?1, lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "all",
                        "count": count($sorted)
                    }
                }
        }
};

declare function rview:output-person-all($list, $letter as xs:string,  $search as xs:string?) {
    array {
        for $person in $list
        (: let $dates := pmf:get-dates($person?3) :)
        let $letterParam := if ($letter = "all") then substring($person?3/@n, 1, 1) else $letter
        return
            <span class="split-list-item">
                <a href="people/{$person?3/@xml:id}">{$person?2}</a>
            </span>
    }
};

declare function rview:person-html($request as map(*)) {
    let $id := xmldb:decode-uri($request?parameters?id)
    let $pers := collection($config:register-root)/id($id)
    let $config := tpu:parse-pi(root($pers), $request?parameters?view, $request?parameters?odd)
    let $extConfig := map {
        "data": map {
            "id": $id,
            "root": $pers,
            "transform": $pm-config:web-transform(?, ?, $config?odd)
        }
    }
    return
        vapi:html($request, $extConfig)
};

declare function rview:person($request as map(*)) {
    let $id := xmldb:decode-uri($request?parameters?id)
    let $pers := collection($config:register-root)/id($id)
    let $params := 
        map {
            "root": $pers,
            "view": "single",
            "odd": $config:default-odd,
            "entity": "yes"
        }
    return
        $pm-config:web-transform($pers, $params, $config:default-odd)
};