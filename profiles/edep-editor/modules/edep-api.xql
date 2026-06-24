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
    let $loc := $config:register-root || "/places/" || $request?parameters?id || ".xml"
    return if (not(doc-available($loc))) then
        error($errors:NOT_FOUND)
    else
        let $return := doc($loc)
        return try { $return } catch * { () }
};

declare function edep:geopicker-places($request as map(*)) {
    let $places := collection($config:register-root || "/places")//tei:place
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
    let $id := 
        if ($request?parameters?id and not(empty($request?body//@xml:id))) then
            let $store := xmldb:store($config:register-root || "/places", concat($request?parameters?id, ".xml"), $request?body)
            return $request?body//@xml:id

        else if ($request?body//@xml:id) then
            let $id := $request?body//@xml:id
            let $store := xmldb:store($config:register-root || "/places", concat($id, ".xml"), $request?body)
            return $id
        else
            let $ids := sort(collection($config:register-root || "/places")//@xml:id/string())
            let $id-new := if (empty($ids)) then "000000" else format-number(xs:integer(replace($ids[last()], "G", "")) + 1, "000000")
            let $store := xmldb:store($config:register-root || "/places", concat("G", $id-new, ".xml"), $request?body)
            let $update := update insert attribute xml:id {concat("G", $id-new)} into doc($store)/tei:place
            return concat("G", $id-new)
    return try {
        doc(concat($config:register-root || "/places", $id, ".xml"))
    } catch * {
        ()
    }
};

declare function edep:load-person($request as map(*)) {
    let $loc := $config:register-root || "/people/" || $request?parameters?id || ".xml"
    return if (not(doc-available($loc))) then
        error($errors:NOT_FOUND)
    else
        let $return := doc($loc)
        return try { $return } catch * { () }
};

declare function edep:person-add($request as map(*)) {
    let $people := $config:register-root || "/people"
    let $id := if ($request?parameters?id and not(empty($request?body//@xml:id))) then
            let $store := xmldb:store($people, concat($request?parameters?id, ".xml"), $request?body)
            return $request?body//@xml:id

        else if ($request?body//@xml:id) then
            let $id := $request?body//@xml:id
            let $store := xmldb:store($people, concat($id, ".xml"), $request?body)
            return $id
        else
            let $ids := sort(collection($people)//@xml:id/string())
            let $id-new := if (empty($ids)) then "000000" else format-number(xs:integer(replace($ids[last()], "P", "")) + 1, "000000")
            let $withId :=
                <person xmlns="http://www.tei-c.org/ns/1.0" xml:id="P{$id-new}">
                {
                    $request?body//tei:person/@sex,
                    $request?body/tei:person/*
                }
                </person>
            let $store := xmldb:store($people, concat("P", $id-new, ".xml"), $withId)
            return concat("P", $id-new)

    return try {
        doc($people || "/" || $id || ".xml")
    } catch * {
        ()
    }
};

declare function edep:inscription($request as map(*)) {
    let $check-collection :=
        if (not(xmldb:collection-available($config:app-root || "/workspace"))) then
            xmldb:create-collection($config:app-root, "/workspace")
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
            let $ids := sort(collection($collection)//tei:idno[@type="EDEp"][not(contains(.,'-'))]/text())
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

declare function edep:fragment($request as map(*)) {
    let $check-collection :=
        if (not(xmldb:collection-available($config:app-root || "/workspace"))) then
            xmldb:create-collection($config:app-root, "/workspace")
        else
            ()
    let $collection := $config:data-root || "/" || $request?parameters?collection

    let $parentId := $request?body/*/@xml:id
    let $log := util:log('info','***** paren id ' || $parentId)

    let $fragments :=
        string-join(
            collection($config:data-root)//*[@corresp = $parentId]//tei:idno[@type='EDEp'],
            ' '
        )
    let $fragmentCnt := fn:count(tokenize($fragments,' ')) + 1

    let $newId := $parentId || "-" || $fragmentCnt
    let $log := util:log('info','***** new fragment id ' || $newId)
    let $rewritten := edep:clean($request?body, $newId, true())
    (: store the parent doc first to keep potential changes   :)
    let $store := xmldb:store($collection, concat($parentId, ".xml"), edep:clean($request?body, $parentId, true()))
    (: store the new fragment doc   :)
    let $store1 := xmldb:store($collection, concat($newId, ".xml"), edep:clean($rewritten, $newId, true()))

    return $rewritten
};

declare function edep:add-fragments-attr(
    $tei       as element(tei:TEI),
    $fragments as xs:string
) as element(tei:TEI) {
    element { node-name($tei) } {
        $tei/@* except $tei/@fragments,
        if( not(exists($tei/@type)) or not($tei/@type='partial')) then attribute fragments { $fragments } else (),
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
                if(not(exists($input/@corresp)) or $input/@corresp = '') then
                    string-join(
                        collection($config:data-root)//*[@corresp = $id]/@xml:id,
                        ' '
                    )
                else 'xxx'

            return
                if (string-length($fragments) != 0 and string-length($input/@corresp) = 0) then
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
                if(contains($edepId,'-')) then (
                    let $seed := substring-before($edepId,'-')
                    return
                    element { node-name($node) } {
                        $node/@* except ($node/@xml:id, $node/@corresp, $node/@type),
                        attribute xml:id { $edepId },
                        attribute corresp { $seed },
                        attribute type {'partial'},
                        edep:postprocess($node/tei:teiHeader, $edepId),
                        root($node)//tei:facsimile,
                        edep:postprocess($node/tei:text, $edepId)
                    }
               )else
                    element { node-name($node) } {
                        $node/@* except ($node/@xml:id),
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
