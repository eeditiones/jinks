xquery version "3.1";

module namespace edep="http://e-editiones.org/api/edep";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace zotero = "http://e-editiones.org/edep/api/zotero" at "zotero.xql";

declare namespace json="http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace sm="http://exist-db.org/xquery/securitymanager";
declare namespace fore = "http://teipublisher.com/ns/fore";

declare variable $edep:inscription-templ := $config:app-root || "/templates/fore/epidoc-template.xml";

declare function edep:places-browse($request as map(*)) {
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    let $places :=
        if ($search and $search != '') then
            collection($config:data-root || "/places")//tei:place[ft:query(tei:placeName, $search || '*')] |
            collection($config:data-root || "/places")//tei:place[contains(@xml:id, $search)]
        else
            collection($config:data-root || "/places")//tei:place
    let $sorted :=
        for $place in $places
        order by $place/tei:placeName[@type="modern"]
        return
            $place
    let $letter :=
        if (count($places) < $limit) then
            "Alle"
        else if ($letterParam = '') then
            substring($sorted[1], 1, 1) => upper-case()
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'Alle') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with(lower-case($entry/tei:placeName[@type="modern"]), lower-case($letter))
            })
    return
        map {
            "items": edep:output-place($byLetter, $letter, $search),
            "categories":
                if (count($places) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with(lower-case($entry/tei:placeName[@type="modern"]), lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "Alle",
                        "count": count($sorted)
                    }
                }
        }
};

declare function edep:output-place($list, $category as xs:string, $search as xs:string?) {
    array {
        for $place in $list
        let $categoryParam := if ($category = "all") then substring($place/@n, 1, 1) else $category
        let $params := "id=" || $place/@xml:id || "&amp;category=" || $categoryParam || "&amp;search=" || $search
        let $label := string-join((
            $place/tei:placeName[@type='modern'][node()],
            $place/tei:placeName[@type='ancient'][node()],
            $place/tei:region[@type='ancient'][node()],
            $place/tei:region[@type='province'][node()],
            $place/tei:placeName[@type='findspot'][node()]
        ), '; ')
        let $coords := tokenize($place/tei:location/tei:geo)
        return
            <div class="place">
                <a href="geodata.html?{$params}">{$label}</a>
                <paper-icon-button id="{$place/@xml:id}" class="place-id" icon="icons:content-copy"
                    title="ID kopieren"></paper-icon-button>
            </div>
    }
};

declare function edep:find-spot($request as map(*)) {
    let $doc := xmldb:decode($request?parameters?id)
    let $xml := doc($config:data-root || '/' || $doc)
    let $placeIds := $xml//tei:origPlace/@corresp
    let $places := for $placeId in $placeIds return collection($config:data-root || "/places")/id($placeId)
    return
        array {
            for $place in $places
            let $tokenized := tokenize($place/tei:location/tei:geo, ',\s*')
            return
                map {
                    "latitude": $tokenized[1],
                    "longitude": $tokenized[2],
                    "label": $place/tei:placeName[@type eq 'findspot']/string()
                }
        }
};

declare function edep:load-place($request as map(*)) {
    let $loc := concat($config:places, $request?parameters?id, ".xml")
    return if (not(doc-available($loc))) then
        error($errors:NOT_FOUND)
    else
        let $return := doc($loc)
        return try { $return } catch * { () }
};

declare function edep:geopicker-places($request as map(*)) {
    let $places := collection($config:data-root || "/places")//tei:place
    return
        <data xmlns="http://www.tei-c.org/ns/1.0">
        {
            for $place in $places
            order by $place/placeName[@type="findspot"]
            return
                <place xml:id="{$place/@xml:id}">
                    {$place/tei:placeName[@type="findspot"]}
                </place>
        }
        </data>
};

declare function edep:places-add($request as map(*)) {
    let $id := if ($request?parameters?id and not(empty($request?body//@xml:id))) then
            let $store := xmldb:store($config:places, concat($request?parameters?id, ".xml"), $request?body)
            return $request?body//@xml:id

        else if ($request?body//@xml:id) then
            let $id := $request?body//@xml:id
            let $store := xmldb:store($config:places, concat($id, ".xml"), $request?body)
            return $id
        else
            let $ids := sort(collection($config:places)//@xml:id/string())
            let $id-new := if (empty($ids)) then "000000" else format-number(xs:integer(replace($ids[last()], "G", "")) + 1, "000000")
            let $store := xmldb:store($config:places, concat("G", $id-new, ".xml"), $request?body)
            let $update := update insert attribute xml:id {concat("G", $id-new)} into doc(concat($config:places, "G", $id-new, ".xml"))/tei:place
            return concat("G", $id-new)

    return try {
        doc(concat($config:places, $id, ".xml"))
    } catch * {
        ()
    }
};

declare function edep:people-browse($request as map(*)) {
    let $search := normalize-space($request?parameters?search)
    let $letterParam := $request?parameters?category
    let $limit := $request?parameters?limit
    let $people :=
        if ($search and $search != '') then
            collection($config:data-root || "/people")//tei:person[ft:query(tei:persName, $search || '*')]
        else
            collection($config:data-root || "/people")//tei:person
    let $sorted :=
        for $person in $people
        order by $person/tei:persName[@type='nomen']
        return
            $person
    let $letter :=
        if (count($people) < $limit) then
            "Alle"
        else if ($letterParam = '') then
            substring($sorted[1], 1, 1) => upper-case()
        else
            $letterParam
    let $byLetter :=
        if ($letter = 'Alle') then
            $sorted
        else
            filter($sorted, function($entry) {
                starts-with(lower-case($entry/tei:persName/tei:name[@type='nomen']), lower-case($letter))
            })
    return
        map {
            "items": edep:output-person($byLetter, $letter, $search),
            "categories":
                if (count($people) < $limit) then
                    []
                else array {
                    for $index in 1 to string-length('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                    let $alpha := substring('ABCDEFGHIJKLMNOPQRSTUVWXYZ', $index, 1)
                    let $hits := count(filter($sorted, function($entry) { starts-with(lower-case($entry/tei:persName/tei:name[@type='nomen']), lower-case($alpha))}))
                    where $hits > 0
                    return
                        map {
                            "category": $alpha,
                            "count": $hits
                        },
                    map {
                        "category": "Alle",
                        "count": count($sorted)
                    }
                }
        }
};

declare function edep:output-person($list, $category as xs:string, $search as xs:string?) {
    array {
        for $person in $list
        let $categoryParam := if ($category = "all") then substring($person/tei:persName/tei:name[@type='nomen'], 1, 1) else $category
        let $params := "id=" || $person/@xml:id || "&amp;category=" || $categoryParam || "&amp;search=" || $search
        let $label := string-join((
            $person/tei:persName/tei:name[@type='praenomen'][node()],
            $person/tei:persName/tei:name[@type='cognomen'][node()],
            $person/tei:persName/tei:name[@type='nomen'][node()]
        ), ' ')
        return
            <span class="person">
                <a href="person.html?{$params}">{$label}</a>
                <paper-icon-button id="{$person/@xml:id}" class="place-id" icon="icons:content-copy"
                    title="ID kopieren"></paper-icon-button>
            </span>
    }
};

declare function edep:load-person($request as map(*)) {
    let $loc := concat($config:people, $request?parameters?id, ".xml")
    return if (not(doc-available($loc))) then
        error($errors:NOT_FOUND)
    else
        let $return := doc($loc)
        return try { $return } catch * { () }
};

declare function edep:person-add($request as map(*)) {
    let $id := if ($request?parameters?id and not(empty($request?body//@xml:id))) then
            let $store := xmldb:store($config:people, concat($request?parameters?id, ".xml"), $request?body)
            return $request?body//@xml:id

        else if ($request?body//@xml:id) then
            let $id := $request?body//@xml:id
            let $store := xmldb:store($config:people, concat($id, ".xml"), $request?body)
            return $id
        else
            let $ids := sort(collection($config:people)//@xml:id/string())
            let $id-new := if (empty($ids)) then "000000" else format-number(xs:integer(replace($ids[last()], "P", "")) + 1, "000000")
            let $withId :=
                <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="P{$id-new}">
                {
                    $request?body//tei:person/@sex,
                    $request?body/tei:person/*
                }
                </person>
            let $store := xmldb:store($config:people, concat("P", $id-new, ".xml"), $withId)
            return concat("P", $id-new)

    return try {
        doc(concat($config:people, $id, ".xml"))
    } catch * {
        ()
    }
};

declare function edep:inscription($request as map(*)) {
    let $check-collection :=
        if (not(xmldb:collection-available($config:inscription))) then
            xmldb:create-collection("/", $config:inscription)
        else
            ()
    let $collection := $config:data-root || "/" || $request?parameters?collection
    let $id :=
        if ($request?parameters?id and $request?parameters?id != '') then
            let $store := xmldb:store($collection, concat($request?parameters?id, ".xml"), edep:clean($request?body, $request?parameters?id, true()))
            return $request?body//tei:idno[@type="EDEp"]/text()
        else if ($request?body//tei:idno[@type="EDEp"]/node()) then
            let $edepId := $request?body//tei:idno[@type="EDEp"]/text()
            let $store := xmldb:store($collection, concat($edepId, ".xml"), edep:clean($request?body, $edepId, true()))
            return $request?body//tei:idno[@type="EDEp"]/text()
        else
            let $ids := sort(collection($collection)//tei:idno[@type="EDEp"]/text())
            let $id-new := if (empty($ids)) then "0000001" else format-number(xs:integer(replace($ids[last()], "E", "")) + 1, "0000000")
            let $store := xmldb:store($collection, concat("E", $id-new, ".xml"), edep:clean($request?body, "E" || $id-new, true()))
            return concat("E", $id-new)
    return try {
        let $preprocessing := map {
            "parameters": map {
                "id": $id,
                "collection": $request?parameters?collection
            }
        }
        return edep:inscription-template($preprocessing)
    } catch * {
        ()
    }
};

declare function edep:add-fragments-attr(
    $tei       as element(tei:TEI),
    $fragments as xs:string
) as element(tei:TEI) {
    element { node-name($tei) } {
        $tei/@* except $tei/@fragments,
        attribute fragments { $fragments },
        $tei/node()
    }
};

declare function edep:inscription-template($request as map(*)) {
    let $id         := $request?parameters?id
    let $collection := $config:data-root || "/" || $request?parameters?collection

    let $doc :=
        if ($id and $id != '') then
            let $input :=
                (
                    collection($collection)//tei:idno[@type = "EDEp"][. = $id]/ancestor::tei:TEI,
                    collection($collection)//tei:idno[. = $id]/ancestor::tei:TEI,
                    doc($collection || "/" || $id || ".xml")/tei:TEI
                )[1]

            let $fragments :=
                string-join(
                    collection($config:data-root)//*[@corresp = $id]//tei:idno[@type='EDEp'],
                    ' '
                )

            return
                if (string-length($fragments) != 0) then
                    document {
                        edep:add-fragments-attr($input, $fragments)
                    }
                else
                    root($input)
        else
            doc($edep:inscription-templ)

    return
        try {
            $doc
        } catch * {
            ()
        }
};

declare function edep:render($request as map(*)) {
    let $type := $request?parameters?type
    let $xml :=
        switch ($type)
            case "transcription" return
                $request?body//tei:div[@type="edition"]
            default return
                $request?body
    return
        $pm-config:web-transform(edep:clean-namespace($xml), map { "root": $xml, "webcomponents": 7 }, $config:default-odd)
};

declare %private function edep:clean($nodes as node()*, $edepId as xs:string?, $removeRedundant as xs:boolean?) {
    let $output := edep:postprocess($nodes, $edepId) => edep:clean-namespace()
    let $cleaned := if ($removeRedundant) then $pm-config:tei-transform($output, map{}, 'edep-clean.odd') else $output
    return
        $cleaned
};

declare %private function edep:postprocess($nodes as node()*, $edepId as xs:string?) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document { edep:postprocess($node/node(), $edepId) }
            case element(tei:msPart) return
                element { node-name($node) } {
                    $node/@*,
                    edep:postprocess($node/* except ($node/tei:div, $node/tei:facsimile), $edepId)
                }
            case element(tei:idno) return
                if ($node/@type = "EDEp" and exists($edepId)) then
                    element { node-name($node) } {
                        $node/@*,
                        $edepId
                    }
                else
                    $node
            case element(tei:TEI) return
                element { node-name($node) } {
                    $node/@* except $node/@xml:id,
                    attribute xml:id { $edepId },
                    edep:postprocess($node/tei:teiHeader, $edepId),
                    root($node)//tei:facsimile,
                    edep:postprocess($node/tei:text, $edepId)
                }
            case element(tei:body) return
                element { node-name($node) } {
                    $node/@*,
                    root($node)//tei:div[@type=('apparatus', 'translation')],
                    $node/tei:div[@type='edition'],
                    $node/tei:div[@type = "commentary"]
                }
            case element(tei:revisionDesc) return
                element { node-name($node) } {
                    $node/@*,
                    $node/tei:change[@type='created'],
                    <change xmlns="http://www.tei-c.org/ns/1.0"
                        type="{if (empty($node/tei:change)) then 'created' else 'changed'}"
                        when="{current-dateTime()}"
                        who="{sm:id()//sm:real/sm:username/string()}"/>
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    edep:postprocess($node/node(), $edepId)
                }
            default return
                $node
};

declare function edep:clean-namespace($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document { edep:clean-namespace($node/node()) }
            case element() return
                element { QName("http://www.tei-c.org/ns/1.0", local-name($node)) } {
                    $node/@*,
                    edep:clean-namespace($node/node())
                }
            default return
                $node
};
