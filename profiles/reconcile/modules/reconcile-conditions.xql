xquery version "3.1";

(:~
 : Normalizes either wire-protocol query shape — 1.0-draft's "conditions" array, or
 : 0.2's flat "query"/"properties" — into one common descriptor
 : (map { "name": xs:string?, "ids": xs:string*, "properties": array of map {
 : "id", "values", "required", "quantifier", "qualifier" } }) that reconc:candidates
 : (reconcile-api.xql) scores against, and evaluates property/id conditions against
 : a candidate entity.
 :
 : A separate module (like reconcile-fulltext.xql) rather than living in
 : reconcile-api.xql: reconc-cond:resolve-extractor (needed here to run a property's
 : "value" extractor against a candidate, exactly like reconcile-api.xql's own
 : label/property extraction already does) also needs to be usable *from*
 : reconcile-api.xql itself — and reconcile-api.xql is what imports this module, so
 : putting resolve-extractor there instead would make a circular import.
 :)
module namespace reconc-cond = "http://teipublisher.com/api/reconcile/conditions";

(:~ Resolves a "label"/property "value" config entry to a callable extractor. Config
 : values may be a function item (called as-is), or an xs:string containing a
 : *relative* XPath expression (e.g. ".", ".//tei:persName[1]", "@type") evaluated
 : against the entity via util:eval — the entity is bound as $data and the string is
 : appended as a path step ("($data)/" || $xpath). A parenthesized "($data)/" prefix
 : (rather than bare "$data" concatenation) avoids the XPath expression's first token
 : being lexed as part of the variable reference itself (e.g. "$data" || "." would
 : otherwise parse as the single token "$data."). See reconcile/doc/README.md for
 : the function-item-vs-XPath-string tradeoffs. :)
declare function reconc-cond:resolve-extractor($value) as function(*) {
    if ($value instance of function(*)) then
        $value
    else
        function($data as item()*) as item()* {
            util:eval("($data)/" || $value)
        }
};

(:~ Normalizes propertyValue/v — a scalar, an entity-reference {id,name} object, or
 : an array of either — to a plain sequence, always. :)
declare %private function reconc-cond:normalize-values($raw) as item()* {
    if ($raw instance of array(*)) then
        $raw?*
    else
        $raw
};

declare %private function reconc-cond:build-condition($id as xs:string?, $values, $required as xs:boolean, $quantifier as xs:string?, $qualifier as xs:string?) as map(*) {
    map {
        "id": $id,
        "values": reconc-cond:normalize-values($values),
        "required": $required,
        "quantifier": ($quantifier, "any")[1],
        "qualifier": $qualifier
    }
};

(:~ Normalizes a 1.0-draft query's "conditions" array into {name, ids, properties}. :)
declare function reconc-cond:normalize-1.0($query as map(*)) as map(*) {
    let $conditions := $query?conditions?*
    let $name-condition := $conditions[?matchType = "name"][1]
    let $name :=
        if (exists($name-condition)) then
            let $v := $name-condition?propertyValue
            return if ($v instance of map(*)) then ($v?name, $v?id)[1] else $v
        else
            ()
    let $ids :=
        for $c in $conditions[?matchType = "id"]
        for $v in reconc-cond:normalize-values($c?propertyValue)
        return if ($v instance of map(*)) then $v?id else string($v)
    let $properties :=
        array {
            for $c in $conditions[?matchType = "property"]
            return reconc-cond:build-condition($c?propertyId, $c?propertyValue, ($c?required, false())[1], $c?matchQuantifier, $c?matchQualifier)
        }
    return map { "name": $name, "ids": $ids, "properties": $properties }
};

(:~ Normalizes a 0.2 query ({query, properties}) into {name, ids, properties}. 0.2 has
 : no "required"/matchQuantifier/matchQualifier concept — every property condition is
 : optional (a soft boost, never a hard filter) with the default match rule. :)
declare function reconc-cond:normalize-0.2($query as map(*)) as map(*) {
    let $properties :=
        array {
            for $p in $query?properties?*
            return reconc-cond:build-condition($p?pid, $p?v, false(), "any", ())
        }
    return map { "name": $query?query, "ids": (), "properties": $properties }
};

(:~ Escapes regex metacharacters other than "*" (which reconc-cond:matches-value
 : treats specially for WildcardMatch), so a wildcard pattern like "Politik*" doesn't
 : get some other character misinterpreted as regex syntax. :)
declare %private function reconc-cond:escape-regex($s as xs:string) as xs:string {
    replace($s, "([.\\+^$\[\]{}()|])", "\\$1")
};

(:~ Does $actual (one value already extracted from a candidate entity) match one
 : $wanted value (a scalar, or an entity-reference {id,name} object — compared on its
 : "id") per $qualifier:
 :   "ExactMatch"    - exact string equality
 :   "WildcardMatch" - glob match, "*" standing for any run of characters
 :   anything else, including no qualifier at all - case-insensitive exact-or-substring,
 :                     the same "good enough default" spirit as reconc-score:default's
 :                     non-fuzzy tiers (0.2 conditions always use this, since 0.2 has
 :                     no matchQualifier concept). :)
declare function reconc-cond:matches-value($actual as item(), $wanted as item(), $qualifier as xs:string?) as xs:boolean {
    let $want := if ($wanted instance of map(*)) then ($wanted?id, $wanted?name)[1] else string($wanted)
    let $a := string($actual)
    return
        if ($qualifier eq "ExactMatch") then
            $a eq $want
        else if ($qualifier eq "WildcardMatch") then
            matches($a, "^" || replace(reconc-cond:escape-regex($want), "\*", ".*") || "$", "i")
        else
            let $al := lower-case(normalize-space($a))
            let $wl := lower-case(normalize-space($want))
            return $al eq $wl or contains($al, $wl)
};

(:~ Evaluates one property condition against a candidate entity: $extractor is the
 : type's already-resolved "value" extractor for $condition?id (resolved by the
 : caller via reconc-cond:resolve-extractor — this module doesn't know about
 : reconcile-config.xql's $TYPES map, only reconcile-api.xql does), called against
 : $entity, then $condition?values is reduced against the extracted values per
 : $condition?quantifier: "any" - at least one wanted value matches something
 : extracted; "all" - every wanted value matches something extracted; "none" - no
 : wanted value matches anything extracted. An absent $extractor (the type doesn't
 : define this property at all) means "never matches" — harmless for an optional
 : condition, correctly excludes every candidate for a required one. :)
declare function reconc-cond:evaluate($extractor as function(*)?, $entity as element(), $condition as map(*)) as map(*) {
    let $matched :=
        (: An absent extractor must never match, regardless of quantifier - checked before even
         : looking at $condition?values. Getting this ordering wrong is a real, previously-shipped
         : bug: for quantifier "none", $per-wanted below would be a sequence of false() (one per
         : wanted value, since "some $a in () satisfies ..." is false(), not the empty sequence),
         : and "not(some ... satisfies false())" evaluates to true() - the exact opposite of "never
         : matches" for a type that doesn't define this property at all. :)
        if (empty($extractor)) then
            false()
        else
            let $actual := $extractor($entity)
            let $per-wanted :=
                for $w in $condition?values
                return some $a in $actual satisfies reconc-cond:matches-value($a, $w, $condition?qualifier)
            return
                if (empty($per-wanted)) then
                    false()
                else if ($condition?quantifier eq "all") then
                    every $m in $per-wanted satisfies $m
                else if ($condition?quantifier eq "none") then
                    not(some $m in $per-wanted satisfies $m)
                else
                    some $m in $per-wanted satisfies $m
    return map { "required": $condition?required, "matched": $matched }
};
