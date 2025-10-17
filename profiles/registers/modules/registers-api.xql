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

declare function rview:people-all($request as map(*)) {
    let $people := collection($config:register-root)//tei:person
    let $byKey := for-each($people, function($person as element()) {
        let $label := ($person//tei:persName[@type='sort'], $person//tei:persName[@type="main"])[1]
        return
            [lower-case($label), $person]
    })
    let $sorted := rview:sort($byKey, "asc")
    return array { 
        for $person in $sorted
        where $person?1
        return
            map {
                "id": $person?2/@xml:id/string(),
                "name": $person?2/tei:persName[@type="main"]/string()
            }
     }
};

declare function rview:people-categories($request as map(*)){
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $sortDir := ($request?parameters?dir, 'asc')[1]
    let $limit := head(($request?parameters?limit, -1))
    let $odd := head(($request?parameters?odd, $config:default-odd))
    let $people :=
            if ($search and $search != '') then
                collection($config:register-root)/id($config:register-map?person?id)//tei:person[ft:query(., 'name:(' || $search || '*)')]
            else
                collection($config:register-root)/id($config:register-map?person?id)//tei:person[ft:query(., '*', map {
                        "leading-wildcard": "yes",
                        "filter-rewrite": "yes"
                    })]
    let $byKey := for-each($people, function($person as element()) {
        let $label := ft:field($person, "sort-name")
        return
            [lower-case($label), $label, $person]
    })
    let $sorted := rview:sort($byKey, $sortDir)
    let $letter := 
        if ($limit < 0 or count($people) < $limit) then 
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
            "items": rview:output-person-all($byLetter, $letter, $search, $odd),
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

declare function rview:output-person-all($list as array(*)*, $letter as xs:string,  $search as xs:string?, $odd as xs:string) {
    array {
        for $person in $list
        let $letterParam := if ($letter = "all") then substring($person?3/@n, 1, 1) else $letter
        let $note := 
            $pm-config:web-transform($person?3, map { "mode": "register-overview" }, $odd)
        return
            <div class="split-list-item">
            { $note }
            </div>
    }
};

declare function rview:detail-html($request as map(*)) {
    let $id := xmldb:decode-uri($request?parameters?id)
    let $entry := collection($config:register-root)/id($id)
    let $config := tpu:parse-pi(root($entry), $request?parameters?view, $request?parameters?odd)
    let $mentions := 
        if ($entry instance of element(tei:person)) then
            collection($config:data-default)//tei:persName[@key = $id]/ancestor::tei:TEI
        else if ($entry instance of element(tei:bibl)) then
            collection($config:data-default)//tei:bibl[@key = $id]/ancestor::tei:TEI
        else
            collection($config:data-default)//tei:placeName[@key = $id]/ancestor::tei:TEI
    let $extConfig := map {
        "data": map {
            "id": $id,
            "root": $entry,
            "letters": $mentions,
            "transform": vapi:transform-helper(?, ?, $config?odd),
            "transform-with": vapi:transform-helper#3
        }
    }
    return
        vapi:html($request, $extConfig)
};

declare function rview:places($request as map(*)){
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    let $odd := head(($request?parameters?odd, $config:default-odd))
    let $places :=
        if ($search and $search != '') then 
            collection($config:register-root)/id($config:register-map?place?id)//tei:place[ft:query(., 'name:(' || $search || '*)')]
        else
            collection($config:register-root)/id($config:register-map?place?id)//tei:place
    let $sorted := sort($places, "?lang=de-DE", function($place) { lower-case(($place/tei:placeName)[1]) })
    let $letter := 
        if (count($places) < $limit) then 
            "all"
        else if ($letterParam = '') then
            substring($sorted[1], 1, 1) => upper-case()
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'all') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with(lower-case(($entry/tei:placeName)[1]), lower-case($letter))
            })
    return
        map {
            "items": rview:output-place($byLetter, $letter, $search, $odd),
            "categories":
                if (count($places) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with(lower-case(($entry/tei:placeName)[1]), lower-case($alpha))}))
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

declare function rview:output-place($list, $category as xs:string, $search as xs:string?, $odd as xs:string) {
    array {
        for $place in $list
            let $label := ($place/tei:placeName)[1]/string()
            let $id := $place/@xml:id
            let $alt := $place/tei:placeName[@type='alt']
            let $note := 
                $pm-config:web-transform($place, map { "mode": "register-overview" }, $odd)
            let $coords := tokenize($place/tei:location/tei:geo)
        return
            <div class="place split-list-item">
            { $note }
            </div>
    }
};

declare function rview:places-all($request as map(*)) {
    let $places := collection($config:register-root)/id("pb-places")//tei:place
    return 
        array { 
            for $place in $places[tei:location/tei:geo/text()]
                let $geo := $place/tei:location/tei:geo
                let $coords := tokenize($geo, ' ')
                return 
                    map {
                        "latitude":$coords[1],
                        "longitude":$coords[2],
                        "label":($place/tei:placeName)[1]/string(),
                        "id": $place/@xml:id/string()
                    }
            }        
};

declare function rview:geonames-link($id) {
    let $geo := substring-after($id, 'geo-')

    return
    if ($geo) then
            <a href="https://www.geonames.org/{$geo}" target="_blank">
                w geonames
                <iron-icon icon="maps:place"/> 
            </a>      
    else 
        ()
};

declare function rview:bibliography-all($request as map(*)) {
    (: all text content is used as label :)
    let $entries := collection($config:register-root)//tei:bibl
    let $byKey := for-each($entries, function($entry as element()) {
        let $label := normalize-space($entry)
        return
            [lower-case($label), $entry]
    })
    let $sorted := rview:sort($byKey, "asc")
    return array { 
        for $entry in $sorted
        where $entry?1
        return
            map {
                "id": $entry?2/@xml:id/string(),
                "name": normalize-space($entry?2)
            }
     }
};

declare function rview:bibliography-categories($request as map(*)){
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $sortDir := ($request?parameters?dir, 'asc')[1]
    let $limit := head(($request?parameters?limit, -1))
    let $odd := head(($request?parameters?odd, $config:default-odd))
    let $entries :=
            if ($search and $search != '') then
                collection($config:register-root)/id($config:register-map?bibliography?id)//tei:bibl[ft:query(., 'name:(' || $search || '*)')]
            else
                collection($config:register-root)/id($config:register-map?bibliography?id)//tei:bibl
    let $byKey := for-each($entries, function($entry as element()) {
        let $label := normalize-space($entry)
        return
            [lower-case($label), $label, $entry]
    })
    let $sorted := rview:sort($byKey, $sortDir)
    let $letter := 
        if ($limit < 0 or count($entries) < $limit) then 
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
            "items": rview:output-bibliography-all($byLetter, $letter, $search, $odd),
            "categories":
                if (count($entries) < $limit) then
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

declare function rview:output-bibliography-all($list as array(*)*, $letter as xs:string,  $search as xs:string?, $odd as xs:string) {
    array {
        for $entry in $list
        let $letterParam := if ($letter = "all") then substring($entry?3/@n, 1, 1) else $letter
        let $note := 
            $pm-config:web-transform($entry?3, map { "mode": "register-overview" }, $odd)
        return
            <div class="split-list-item">
            { $note }
            </div>
    }
};