xquery version "3.1";

module namespace sheet="http://e-editiones.org/edep/sheet";

import module namespace global="http://e-editiones.org/tei-publisher/odd-global" at "odd-global.xqm";

declare function sheet:lang($parameters as map(*)?) as xs:string {
    (tokenize(normalize-space(string($parameters?language)), "-")[1][. = ("de", "en")], "de")[1]
};

declare function sheet:plain($value as item()*) as xs:string? {
    normalize-space(string-join($value, " "))[.]
};

declare function sheet:label($parameters as map(*)?, $file as xs:string, $attr as xs:string, $key as item()?) as xs:string? {
    let $k := replace(normalize-space(string($key)), "^#", "")
    let $lang := sheet:lang($parameters)
    let $cat :=
        if ($k = "") then ()
        else try {
            doc($global:app-root || "/data/taxonomy/" || $file)//*:category[@*[local-name() = $attr] = $k]
        } catch * { () }
    let $label := ($cat/*:catDesc[@xml:lang = $lang], $cat/*:catDesc)[normalize-space(.)][1]
    return
        if ($k = "") then ()
        else if ($label) then string($label)
        else $k
};

declare function sheet:labels($parameters as map(*)?, $file as xs:string, $attr as xs:string, $keys as item()*) as xs:string? {
    let $labels := for $key in $keys return sheet:label($parameters, $file, $attr, $key)
    return if (empty($labels)) then () else string-join($labels, ", ")
};

declare function sheet:join($value as item()*, $separator as xs:string) as xs:string? {
    let $parts := $value ! normalize-space(string(.))[.]
    return if (empty($parts)) then () else string-join($parts, $separator)
};

declare function sheet:place-name($id as item()?, $type as xs:string) as xs:string? {
    let $placeId := sheet:plain($id)
    let $place := collection($global:register-root || "/places")/*[@xml:id = $placeId]
    return sheet:join($place/*:placeName[@type = $type], ", ")
};

declare function sheet:cm($node as node()*) as xs:string? {
    let $n := sheet:plain($node)
    return if ($n) then $n || " cm" else ()
};

declare function sheet:languages($usage as element()?, $parameters as map(*)?) as xs:string? {
    let $values :=
        for $language in $usage/*:language[@ident][not(@ident = ("edep", ""))]
        return sheet:label($parameters, "languages.xml", "id", $language/@ident)
    return if (empty($values)) then () else string-join($values, ", ")
};

declare function sheet:dating($date as element()?, $parameters as map(*)?) as xs:string? {
    if (empty($date)) then ()
    else
        let $lang := sheet:lang($parameters)
        let $after := if ($lang = "en") then "after" else "nach"
        let $before := if ($lang = "en") then "before" else "vor"
        return sheet:plain(string-join((
            sheet:plain($date/@when-custom),
            if (sheet:plain($date/@notBefore-custom)) then $after || " " || sheet:plain($date/@notBefore-custom) else (),
            if (sheet:plain($date/@notAfter-custom)) then $before || " " || sheet:plain($date/@notAfter-custom) else ()
        )[.], ", "))
};

declare function sheet:term-label($parameters as map(*)?, $key as item()?) as xs:string? {
    let $k := replace(normalize-space(string($key)), "^#", "")
    let $lang := sheet:lang($parameters)
    return
        switch ($k)
            case "social-economic-legal-history" return if ($lang = "en") then "Social / Economic / Legal History" else "Sozial-/Wirtschafts-/Rechtsgeschichte"
            case "geography" return if ($lang = "en") then "Geography / Topography" else "Geographie / Topographie"
            case "military" return if ($lang = "en") then "Military" else "Militär"
            case "" return ()
            default return $k
};

declare function sheet:relevance($keywords as element()*, $parameters as map(*)?) as xs:string? {
    let $values := (
        for $ref in $keywords[contains(@scheme, "religion")]/*:term/@ref
        return sheet:label($parameters, "religion.xml", "id", $ref),
        for $ref in $keywords[contains(@scheme, "/terms")]/*:term/@ref
        return sheet:term-label($parameters, $ref)
    )
    return if (empty($values)) then () else string-join($values, ", ")
};

declare function sheet:editor($editor as element(), $parameters as map(*)?) as xs:string? {
    sheet:plain(string-join((
        sheet:label($parameters, "editor-roles.xml", "id", $editor/@role),
        sheet:plain($editor)
    )[.], ", "))
};

declare function sheet:edit-date($revision as element()?) as xs:string? {
    let $times :=
        for $when in $revision/*:change/@when
        return try { xs:dateTime(normalize-space(string($when))) } catch * { () }
    return if (empty($times)) then () else format-dateTime(max($times), "[Y0001]-[M01]-[D01]")
};

declare function sheet:letter-height($notes as element()*) as xs:string? {
    let $lines :=
        for $note in $notes
        let $locus := sheet:plain($note/*:locus)
        let $height := $note/*:dimensions/*:height[1]
        let $min := sheet:plain($height/@min)
        let $max := sheet:plain($height/@max)
        let $range :=
            if ($min and $max and $min != $max) then $min || "–" || $max
            else ($min, $max)[.][1]
        let $measure := string-join(($range, sheet:plain($height))[.], "; ")
        return sheet:plain(string-join(($locus, $measure)[.], ": "))
    return if (empty($lines)) then () else string-join($lines, "; ")
};

declare function sheet:language-scope($languages as element()*, $parameters as map(*)?) as xs:string? {
    let $values :=
        for $language in $languages
        return (sheet:label($parameters, "language-scope.xml", "id", $language/@ana), "–")[1]
    return if (empty($values)) then () else string-join($values, ", ")
};
