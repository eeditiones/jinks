xquery version "3.1";

module namespace reconc="http://teipublisher.com/api/reconcile";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace reconc-config="http://teipublisher.com/api/reconcile/config" at "reconcile-config.xql";
import module namespace reconc-cond="http://teipublisher.com/api/reconcile/conditions" at "reconcile-conditions.xql";
import module namespace router="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ All entity types this service can be reconciled against are defined in
 : reconcile-config.xql ($reconc-config:TYPES) — see that file for how to add, remove or
 : redefine a type, or swap the matching/ranking algorithm ($reconc-config:SCORE). This
 : module only implements the HTTP-facing reconciliation protocol on top of it. :)

(:~ Config-value-to-extractor resolution (function item or XPath string) lives in
 : reconc-cond:resolve-extractor (reconcile-conditions.xql) — needed there too, for
 : evaluating property match conditions, and this module already imports that one. :)

(:~ All registered entities for a reconciliation type id, e.g. "person". :)
declare %private function reconc:entities($type-id as xs:string) as element()* {
    let $type-def := $reconc-config:TYPES?($type-id)
    return
        if (exists($type-def)) then
            ($type-def?entities)()
        else
            ()
};

(:~ Finds a single entity by id across all reconciliation types. Returns a map
 : {entity, type-id}, or the empty sequence if no type's register contains it. :)
declare %private function reconc:entity-by-id($id as xs:string) as map(*)? {
    let $match :=
        for $type-id in map:keys($reconc-config:TYPES)
        let $entity := reconc:entities($type-id)[@xml:id = $id]
        where exists($entity)
        return map { "entity": $entity, "type-id": $type-id }
    return head($match)
};

(:~ Human-readable label for a matched entity, per its type's configured "label" extractor. :)
declare %private function reconc:label($entity as element(), $type-id as xs:string) as xs:string {
    let $extractor := reconc-cond:resolve-extractor($reconc-config:TYPES?($type-id)?label)
    let $raw := $extractor($entity)
    return normalize-space(string-join(for $r in $raw return string($r), " "))
};

(:~ Every name-variant string worth matching a query against for an entity, per its
 : type's optional "labels" (plural) extractor. Falls back to a single-element
 : sequence containing just reconc:label(...) when no "labels" extractor is
 : configured (or it produces nothing usable) — so scoring for types that don't set
 : it (this profile's own "organization"/"work" defaults, or any custom type) is
 : identical to before "labels" existed. :)
declare %private function reconc:labels($entity as element(), $type-id as xs:string) as xs:string* {
    let $labels-def := $reconc-config:TYPES?($type-id)?labels
    let $variants :=
        if (exists($labels-def)) then
            let $extractor := reconc-cond:resolve-extractor($labels-def)
            for $r in $extractor($entity)
            let $s := normalize-space(string($r))
            where $s != ""
            return $s
        else
            ()
    return
        if (exists($variants)) then
            $variants
        else
            (reconc:label($entity, $type-id))
};

declare %private function reconc:normalize-text($s as xs:string?) as xs:string {
    lower-case(normalize-space($s))
};

(:~ Reads a reconciliation "type" value, which may be absent, a single string, or an array of strings. :)
declare %private function reconc:normalize-types($type) as xs:string* {
    if (empty($type)) then
        ()
    else if ($type instance of array(*)) then
        $type?*
    else
        $type
};

(:~ Defends the per-query batch loop against a malformed or absent entry — e.g. a
 : blank OpenRefine cell serialized as JSON null, or any other non-object value —
 : by treating it as an empty query (no name/ids/properties, so it always scores
 : zero candidates) instead of raising a fatal type error that would abort the
 : *entire* batch response for every other, well-formed query in it. Confirmed
 : live against real OpenRefine traffic: a single null/non-object entry anywhere
 : in a batch used to turn into an HTTP 500 for the whole request (reconc-cond:
 : normalize-1.0/0.2 both require "$query as map(*)" and reject anything else),
 : which is far worse than "no candidates" for just that one row. :)
declare %private function reconc:as-query-map($query as item()*) as map(*) {
    if ($query instance of map(*)) then $query else map {}
};

(:~ Parses a "limit" value into a valid xs:integer, capped at MAX_LIMIT, defaulting to
 : $default on anything that isn't a valid integer (e.g. a non-numeric string) instead
 : of raising a fatal cast error — same "one bad row must not crash the whole batch"
 : reasoning as reconc:as-query-map. Confirmed live: an unparsable "limit" in a
 : reconcile query batch used to turn into an HTTP 500 (err:FORG0001) for the entire
 : batch. Also the required helper for every GET route's own "limit" query parameter
 : (suggest/entity, suggest/property, suggest/type, extend/propose) — those params must
 : be declared "type": "string" in reconcile-api.tpl.json, not "integer": roaster's own
 : parameter-casting middleware (parameters.xql) calls xs:integer() with no try/catch
 : for a "type": "integer" parameter, so a non-numeric "limit" used to 500 with an
 : internal module path/line leaked in the response *before* this function, or even
 : reconc:suggest-entity itself, ever ran. :)
declare %private function reconc:safe-limit($raw as item()*, $default as xs:integer) as xs:integer {
    let $n :=
        try {
            xs:integer(($raw, $default)[1])
        } catch * {
            $default
        }
    return min(($n, $reconc-config:MAX_LIMIT))
};

(:~ Pre-filters a type's entities via its configured "fulltext-search" closure
 : (see reconcile-config.xql's doc for that field) so only plausible candidates
 : reach the (much more expensive, per-candidate) scoring in reconc:candidates. An
 : empty/blank query can't be turned into a useful Lucene query, so it falls back
 : to every entity of the type — harmless, since an empty query scores 0 against
 : everything anyway and gets filtered out downstream. :)
declare %private function reconc:fulltext-prefilter($type-def as map(*), $query as xs:string?) as element()* {
    if (normalize-space($query) eq "") then
        ($type-def?entities)()
    else
        ($type-def?fulltext-search)($query)
};

(:~ {id, label, labels, entity} for a single matched entity — the per-entity data
 : reconc:candidates actually scores against, however the entity was found (full
 : scan, Lucene pre-filter, or a precomputed batch pool). "entity" is the node
 : itself, needed to evaluate property match conditions (reconc-cond:evaluate) —
 : "id"/"label"/"labels" alone were enough before conditions existed. :)
declare %private function reconc:candidate-entry($entity as element(), $type-id as xs:string) as map(*) {
    map {
        "id": $entity/@xml:id/string(),
        "label": reconc:label($entity, $type-id),
        "labels": reconc:labels($entity, $type-id),
        "entity": $entity
    }
};

(:~ {id, label, labels} for every entity of a type — the expensive part of
 : full-scan matching (reading the whole collection, extracting every name
 : variant) computed once so a batch request can reuse it across queries instead
 : of redoing it per query (see reconc:candidate-pool). Also used directly by
 : reconc:candidates for a single, unpooled query against a type with no
 : "fulltext-search" (where there's no cheaper way to narrow the candidate set). :)
declare %private function reconc:label-pool-for-type($type-id as xs:string) as map(*)* {
    for $e in reconc:entities($type-id)
    return reconc:candidate-entry($e, $type-id)
};

(:~ Builds a batch-wide pool (type id -> reconc:label-pool-for-type's result) for
 : every given type that does *not* have a "fulltext-search" configured — those
 : types have no cheaper way to narrow candidates than a full scan, so it's worth
 : precomputing once per request rather than once per query in the batch. Types
 : *with* a "fulltext-search" are deliberately left out: reconc:fulltext-prefilter
 : is a cheap, indexed, per-query-text lookup, so there's nothing to usefully
 : precompute for them ahead of knowing each query's text. Called once per batch
 : request (reconc:reconcile-1.0/0.2), not once per query. :)
declare %private function reconc:candidate-pool($type-ids as xs:string*) as map(*) {
    map:merge(
        for $type-id in $type-ids
        let $type-def := $reconc-config:TYPES?($type-id)
        where exists($type-def) and empty($type-def?fulltext-search)
        return map:entry($type-id, reconc:label-pool-for-type($type-id))
    )
};

(:~ Runs every property condition in $conditions?properties against one candidate
 : entity, resolving each property's extractor from $type-def?properties (the exact
 : same "value" extractors already used by /extend) — scoped to *this* candidate's
 : own type-def, never a global-by-id lookup (see reconc:extend-response's
 : $value-for for why that matters: two types can define the same property id with
 : different extractors, e.g. this profile's own "gnd" on both "person" and "work").
 : A propertyId the type doesn't define resolves to no extractor at all (not a
 : broken one), so reconc-cond:evaluate correctly treats it as "never matches". :)
declare %private function reconc:evaluate-property-conditions($type-def as map(*), $entity as element(), $conditions as array(*)) as map(*)* {
    for $condition in $conditions?*
    let $prop-def := $type-def?properties?($condition?id)
    let $extractor := if (exists($prop-def)) then reconc-cond:resolve-extractor($prop-def?value) else ()
    return reconc-cond:evaluate($extractor, $entity, $condition)
};

(:~ Find and score candidates for a normalized query descriptor (see
 : reconc-cond:normalize-1.0/normalize-0.2 — {name, ids, properties}), restricted to
 : the given type ids (all default types if empty). $pool optionally supplies
 : precomputed candidate entries for one or more types (see reconc:candidate-pool)
 : — a type missing from $pool (including every type, when $pool is the default
 : map {}) is always resolved fresh here. This is what makes $pool purely a
 : batch-request optimization, never a correctness requirement: single-query
 : callers (e.g. reconc:suggest-entity) simply don't pass one.
 :
 : Candidate *generation* (which entities are even considered) prefers, in order:
 : (1) $conditions?ids, resolved directly via reconc:entity-by-id — cheap, no scan;
 : (2) $conditions?name, via the pool / a type's "fulltext-search" pre-filter / a
 : full scan, exactly as before conditions existed; (3) $conditions?properties
 : alone (no name, no ids — a query can legally have only property conditions, per
 : the spec's own "no query string" example) via a full scan, since there is no
 : index over arbitrary properties, only over the name field.
 :
 : Candidate *scoring* is then uniform regardless of how the entity was found: an
 : id match scores 100, a name match scores via $reconc-config:SCORE, and each
 : matched property condition adds a flat boost (capped at 100 total) — except a
 : *required* condition that does NOT match drops the candidate outright,
 : regardless of any other score component. With no id/property conditions this
 : reduces to exactly the pre-conditions score (name-score alone, boost 0), so
 : existing name-only queries are entirely unaffected. :)
declare %private function reconc:candidates($type-ids as xs:string*, $conditions as map(*), $limit as xs:integer, $pool as map(*)) as map(*)* {
    let $types := if (empty($type-ids)) then map:keys($reconc-config:TYPES) else $type-ids
    let $name := $conditions?name
    let $has-name := exists($name) and normalize-space($name) != ""
    let $id-values := $conditions?ids
    let $properties := ($conditions?properties, [])[1]
    let $items :=
        if (exists($id-values)) then
            for $id in $id-values
            let $found := reconc:entity-by-id($id)
            where exists($found) and $found?type-id = $types
            return map { "type-id": $found?type-id, "entry": reconc:candidate-entry($found?entity, $found?type-id) }
        else
            for $type-id in $types
            let $type-def := $reconc-config:TYPES?($type-id)
            where exists($type-def)
            let $entries :=
                if (map:contains($pool, $type-id)) then
                    $pool($type-id)
                else if ($has-name and exists($type-def?fulltext-search)) then
                    for $e in reconc:fulltext-prefilter($type-def, $name)
                    return reconc:candidate-entry($e, $type-id)
                else
                    reconc:label-pool-for-type($type-id)
            for $entry in $entries
            return map { "type-id": $type-id, "entry": $entry }
    let $scored :=
        for $item in $items
        let $type-id := $item?type-id
        let $type-def := $reconc-config:TYPES?($type-id)
        let $entry := $item?entry
        let $name-score := if ($has-name) then max((xs:double(0), for $l in $entry?labels return ($reconc-config:SCORE)($l, $name))) else xs:double(0)
        let $id-base := if ($entry?id = $id-values) then xs:double(100) else xs:double(0)
        let $prop-results := reconc:evaluate-property-conditions($type-def, $entry?entity, $properties)
        where every $pr in $prop-results[?required eq true()] satisfies $pr?matched
        let $boost := sum(for $pr in $prop-results where $pr?matched return xs:double(20))
        let $score := min((xs:double(100), max(($name-score, $id-base)) + $boost))
        where $score > 0
        return
            map {
                "id": $entry?id,
                "name": $entry?label,
                "type-id": $type-id,
                "score": $score
            }
    let $sorted := sort($scored, (), function($c) { -$c?score })
    return
        subsequence($sorted, 1, max(($limit, 0)))
};

declare %private function reconc:format-candidate($candidate as map(*)) as map(*) {
    map {
        "id": $candidate?id,
        "name": $candidate?name,
        "score": $candidate?score,
        "match": $candidate?score >= 95,
        "type": [
            map {
                "id": $candidate?type-id,
                "name": $reconc-config:TYPES?($candidate?type-id)?name
            }
        ]
    }
};

declare %private function reconc:site-root($request as map(*)) as xs:string {
    let $scheme := request:get-scheme()
    let $host := request:get-server-name()
    let $port := request:get-server-port()
    let $default-port := if ($scheme = "https") then 443 else 80
    let $authority := if ($port = $default-port) then $host else $host || ":" || $port
    let $app-link := substring-after($config:app-root, repo:get-root())
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $app-link), "/")
    return
        $scheme || "://" || $authority || replace($path, "/+", "/")
};

declare %private function reconc:base-url($request as map(*)) as xs:string {
    reconc:site-root($request) || "/api/reconcile"
};

(:~
 : Reconciliation Service Manifest.
 : GET /api/reconcile [?version=0.2|1.0-draft]
 :
 : A single manifest cannot simultaneously satisfy both the 0.2 and 1.0-draft JSON
 : Schemas: 0.2 requires identifierSpace/schemaSpace while 1.0-draft requires a
 : "view" object, and the "suggest" sub-object has incompatible shapes (booleans
 : vs. service-definition objects) between the two. The default (no ?version)
 : manifest is 1.0-draft-only; pass ?version=0.2 to get a 0.2-only manifest. The
 : local reconciliation-api testbench determines the protocol version purely by
 : checking which schema the fetched manifest validates against, so point it at
 : the plain endpoint for a 1.0-draft run and at "?version=0.2" for a 0.2 run.
 :)
declare function reconc:manifest($request as map(*)) {
    let $extend-param := $request?parameters?extend
    return
        if (exists($extend-param) and normalize-space($extend-param) != "") then
            (: Classic (pre-1.0) data-extension convention: GET the service root with an
             : "extend" query parameter, still used by the local reconciliation test bench's
             : data-extension tab. See reconc:extend. :)
            reconc:extend-response(parse-json($extend-param), $request?parameters?version)
        else
            reconc:manifest-response($request)
};

declare %private function reconc:manifest-response($request as map(*)) {
    let $version := $request?parameters?version
    let $base := reconc:base-url($request)
    let $default-types := array {
        map:for-each($reconc-config:TYPES, function($id, $def) { map { "id": $id, "name": $def?name } })
    }
    return
        if ($version = "0.2") then
            map {
                "versions": ["0.2"],
                "name": "TEI Publisher Reconciliation Service",
                "identifierSpace": "https://teipublisher.com/register/id/",
                "schemaSpace": "https://teipublisher.com/register/schema/",
                "defaultTypes": $default-types,
                (: Every sub-service URL below carries "?version=0.2" explicitly, even
                 : though none of these particular endpoints currently behave any
                 : differently with or without it (their response schemas are identical
                 : supersets between 0.2 and 1.0-draft — compare the schemas published at
                 : https://github.com/reconciliation-api/specs). Since this profile serves both
                 : protocol versions from the very same routes, distinguished only by this
                 : query parameter, a strict
                 : 0.2 client that resolves every URL from the 0.2 manifest it just fetched
                 : should consistently stay in "0.2 mode" rather than silently falling back
                 : to the (different) 1.0-draft default the bare URL would otherwise imply —
                 : cheap to keep correct now, and avoids a latent version-mixing bug if any
                 : of these responses ever do diverge behaviorally by version later. :)
                "view": map {
                    "url": $base || "/entity/{{id}}?version=0.2"
                },
                "preview": map {
                    "url": $base || "/preview?id={{id}}&amp;version=0.2",
                    "width": 400,
                    "height": 300
                },
                (: Every suggest.* entry also declares its own flyout_service_path even
                 : though the 0.2 spec says its *absence* should mean "no flyout service" —
                 : OpenRefine's own vendored suggest widget (externals/suggest/suggest-4_3a.js)
                 : does not honor that: it silently falls back to its own hardcoded legacy
                 : Freebase default ("/search...") whenever flyout_service_path isn't given,
                 : which 404s against OUR base URL instead of just doing nothing. Declaring a
                 : real flyout_service_path here is the only way to stop that; see
                 : reconc:suggest-flyout's own doc comment for how this was found. :)
                "suggest": map {
                    "entity": map { "service_url": $base, "service_path": "/suggest/entity?version=0.2", "flyout_service_path": "/suggest/flyout?kind=entity&amp;id=${id}&amp;version=0.2" },
                    "type": map { "service_url": $base, "service_path": "/suggest/type?version=0.2", "flyout_service_path": "/suggest/flyout?kind=type&amp;id=${id}&amp;version=0.2" },
                    "property": map { "service_url": $base, "service_path": "/suggest/property?version=0.2", "flyout_service_path": "/suggest/flyout?kind=property&amp;id=${id}&amp;version=0.2" }
                },
                "extend": map {
                    "propose_properties": map { "service_url": $base, "service_path": "/extend/propose?version=0.2" }
                }
            }
        else
            map {
                "versions": ["1.0-draft"],
                "name": "TEI Publisher Reconciliation Service",
                "view": map {
                    "url": $base || "/entity/{{id}}"
                },
                "defaultTypes": $default-types,
                "preview": map {
                    "url": $base || "/preview?id={{id}}",
                    "width": 400,
                    "height": 300
                },
                "suggest": map {
                    "entity": true(),
                    "property": true(),
                    "type": true()
                },
                "extend": map {
                    "proposeProperties": true()
                },
                "standardizedScore": true()
            }
};

(:~ All type ids a batch of queries could touch — each query's own "type"
 : restriction if given, or every default type for a query that doesn't restrict
 : type at all (matching reconc:candidates' own "empty means all types" rule) —
 : used to build the batch-wide candidate pool once up front (see
 : reconc:candidate-pool) rather than per query. Each query's own type list is
 : passed wrapped in an array; a plain "for $types in ...return $types" here would
 : flatten every query's types into one undifferentiated sequence, since a FLWOR
 : return of a sequence-valued expression flattens — the array keeps them apart
 : until unboxed with "?*" below (this is only needed for gathering the pool's type
 : set, not for reconc:candidates itself, which already accepts a plain sequence). :)
declare %private function reconc:all-queried-types($type-restrictions as array(*)*) as xs:string* {
    distinct-values(
        for $types in $type-restrictions
        let $ids := $types?*
        return if (empty($ids)) then map:keys($reconc-config:TYPES) else $ids
    )
};

declare %private function reconc:reconcile-1.0($body as map(*)) as map(*) {
    (: Deliberately NOT "$body?queries?*" here — unboxing an array that way drops
     : any member holding the empty sequence (i.e. a JSON null entry) entirely,
     : silently shortening the sequence and shifting every later query's result
     : out of its correct position. array:size/positional array access preserves
     : every member, null or not, so reconc:as-query-map below can turn a null
     : into an explicit "no candidates" result at its *original* position instead
     : of making it vanish. Confirmed live: this exact scenario used to produce a
     : "results" array shorter than "queries", which is exactly the mismatch
     : OpenRefine's own batch-shape check (its "No. of recon objects was less
     : than no. of jobs" error) flags as invalid. :)
    let $queries-arr := $body?queries
    let $count := array:size($queries-arr)
    return
        if ($count > $reconc-config:MAX_BATCH_SIZE) then
            error($errors:BAD_REQUEST, "Batch too large: " || $count || " queries (max " || $reconc-config:MAX_BATCH_SIZE || ")")
        else
            let $safe-queries := for $i in 1 to $count return reconc:as-query-map($queries-arr($i))
            let $per-query-types := for $query in $safe-queries return array { reconc:normalize-types($query?type) }
            let $pool := reconc:candidate-pool(reconc:all-queried-types($per-query-types))
            return
                map {
                    "results": array {
                        for $query at $i in $safe-queries
                        let $conditions := reconc-cond:normalize-1.0($query)
                        let $limit := reconc:safe-limit($query?limit, 10)
                        let $candidates := reconc:candidates($per-query-types[$i]?*, $conditions, $limit, $pool)
                        return
                            map {
                                "candidates": array { for $c in $candidates return reconc:format-candidate($c) }
                            }
                    }
                }
};

declare %private function reconc:reconcile-0.2($query-map as map(*)) as map(*) {
    (: map:keys keeps every key regardless of its value (a JSON-null value doesn't
     : remove the key the way a null array member vanishes during unboxing above)
     : — but the *value* itself can still be null/non-object, which used to crash
     : reconc-cond:normalize-0.2's "$query as map(*)" parameter with a fatal type
     : error for the whole batch. reconc:as-query-map guards that the same way. :)
    let $keys := map:keys($query-map)
    return
        if (count($keys) > $reconc-config:MAX_BATCH_SIZE) then
            error($errors:BAD_REQUEST, "Batch too large: " || count($keys) || " queries (max " || $reconc-config:MAX_BATCH_SIZE || ")")
        else
            let $safe-queries := for $key in $keys return reconc:as-query-map($query-map($key))
            let $per-query-types := for $query in $safe-queries return array { reconc:normalize-types($query?type) }
            let $pool := reconc:candidate-pool(reconc:all-queried-types($per-query-types))
            return
                map:merge(
                    for $key at $i in $keys
                    let $query := $safe-queries[$i]
                    let $conditions := reconc-cond:normalize-0.2($query)
                    let $limit := reconc:safe-limit($query?limit, 10)
                    let $candidates := reconc:candidates($per-query-types[$i]?*, $conditions, $limit, $pool)
                    return
                        map:entry($key, map {
                            "result": array { for $c in $candidates return reconc:format-candidate($c) }
                        })
                )
};

(:~
 : Reconciliation query batch.
 : POST /api/reconcile and POST /api/reconcile/match (alias expected by the
 : 1.0-draft test bench, which always posts to "<endpoint>/match").
 :
 : The request shape (not a version parameter) determines which protocol is
 : used: a "queries" array of {conditions:[...]} objects is the 1.0-draft
 : shape; a "queries" object (or the request body itself, per the strict 0.2
 : spec) keyed by arbitrary query ids with {query, type, limit} fields is 0.2.
 :)
declare function reconc:reconcile($request as map(*)) {
    let $raw-body := $request?body
    return
        (: application/x-www-form-urlencoded body {"extend": "<json string>"} — the classic
         : data-extension convention OpenRefine's own Java client actually uses (POST to the
         : base endpoint with a form field named "extend"), distinct from the 1.0-draft
         : canonical POST /extend route with a JSON body. Confirmed against OpenRefine's
         : ReconciledDataExtensionJob.postExtendQuery, which does exactly this — POSTs
         : name="extend" to the plain reconciliation endpoint, not to "/extend". Without this
         : check the form body was falling through to reconc:reconcile-0.2 and being
         : misinterpreted as a batch of one bogus query keyed "extend", silently producing a
         : nonsense 200 response instead of real property values — which is what surfaced in
         : OpenRefine as "Preview: Error" and a data-extension job that never finished. :)
        if ($raw-body?extend instance of xs:string) then
            reconc:extend-response(parse-json($raw-body?extend), $request?parameters?version)
        else
            let $body :=
                (: application/x-www-form-urlencoded: body is {"queries": "<json string>"} —
                 : the classic OpenRefine 0.2 wire format still used by the local 0.2 test
                 : bench. :)
                if ($raw-body?queries instance of xs:string) then
                    map { "queries": parse-json($raw-body?queries) }
                else
                    $raw-body
            return
                if (map:contains($body, "queries") and $body?queries instance of array(*)) then
                    reconc:reconcile-1.0($body)
                else if (map:contains($body, "queries")) then
                    reconc:reconcile-0.2($body?queries)
                else
                    reconc:reconcile-0.2($body)
};

(:~
 : Suggest entities matching a prefix (auto-completion).
 : GET /api/reconcile/suggest/entity?prefix=...&type=...&limit=...
 :)
declare function reconc:suggest-entity($request as map(*)) {
    let $prefix := $request?parameters?prefix
    let $types := reconc:normalize-types($request?parameters?type)
    let $limit := reconc:safe-limit($request?parameters?limit, 10)
    let $candidates := reconc:candidates($types, map { "name": $prefix, "ids": (), "properties": [] }, $limit, map {})
    return
        map {
            "result": array {
                for $c in $candidates
                return
                    map {
                        "id": $c?id,
                        "name": $c?name,
                        "notable": [ map { "id": $c?type-id, "name": $reconc-config:TYPES?($c?type-id)?name } ]
                    }
            }
        }
};

(:~ All {id, name, value, type-id} properties across all types, or just for one type id if given.
 : Treats an empty-string $type-id the same as an absent one (all types) rather than a literal
 : filter that can never match: OpenRefine's own "Add columns from reconciled values" dialog
 : (add-column-by-reconciliation.js) always sends a "type" query parameter, and falls back to
 : "" — never omitting it — whenever the column's own reconConfig didn't record a specific
 : type, so treating "" as a real, non-matching filter silently produced zero properties for
 : exactly that (common) case. :)
declare %private function reconc:properties-for-type($type-id as xs:string?) as map(*)* {
    let $type-id := ($type-id[normalize-space(.) != ""])
    let $types := if (exists($type-id)) then ($type-id) else map:keys($reconc-config:TYPES)
    for $t in $types
    let $props := $reconc-config:TYPES?($t)?properties
    where exists($props)
    return
        map:for-each($props, function($pid, $pdef) {
            map:merge((map { "id": $pid, "type-id": $t }, $pdef))
        })
};

(:~
 : Suggest properties matching a prefix (auto-completion).
 : GET /api/reconcile/suggest/property?prefix=...&type=...&limit=...
 :)
declare function reconc:suggest-property($request as map(*)) {
    let $prefix := reconc:normalize-text($request?parameters?prefix)
    let $type := $request?parameters?type
    let $limit := reconc:safe-limit($request?parameters?limit, 20)
    let $matches :=
        for $p in reconc:properties-for-type($type)
        where $prefix eq "" or contains(reconc:normalize-text($p?id), $prefix) or contains(reconc:normalize-text($p?name), $prefix)
        return map { "id": $p?id, "name": $p?name }
    return
        map { "result": array { subsequence($matches, 1, max(($limit, 0))) } }
};

(:~
 : Suggest reconciliation types matching a prefix (auto-completion).
 : GET /api/reconcile/suggest/type?prefix=...&limit=...
 :)
declare function reconc:suggest-type($request as map(*)) {
    let $prefix := reconc:normalize-text($request?parameters?prefix)
    let $limit := reconc:safe-limit($request?parameters?limit, 20)
    let $matches :=
        map:for-each($reconc-config:TYPES, function($id, $def) {
            if ($prefix eq "" or contains(reconc:normalize-text($id), $prefix) or contains(reconc:normalize-text($def?name), $prefix)) then
                map { "id": $id, "name": $def?name }
            else
                ()
        })
    return
        map { "result": array { subsequence($matches, 1, max(($limit, 0))) } }
};

(:~ XML-escapes a string for safe embedding as HTML text content. Needed because
 : reconc:suggest-flyout builds its "html" field via plain string concatenation, not a
 : real element constructor — unlike reconc:render-html's property-rows table, which
 : gets escaping for free from direct element construction, e.g. <td>{$s}</td>. ("&amp;"
 : below is XQuery's predefined entity reference for a literal "&" character, valid
 : inside any XQuery string literal per the language spec — not XML markup; the search
 : arg "&amp;" is one literal "&", the replacement "&amp;amp;" is the 5-character string
 : "&amp;", same trick reconcile-fulltext.xql's escape-token uses.) :)
declare %private function reconc:escape-html($s as xs:string?) as xs:string {
    if (empty($s)) then
        ""
    else
        replace(replace(replace($s, "&amp;", "&amp;amp;"), "<", "&amp;lt;"), ">", "&amp;gt;")
};

(:~
 : Small HTML preview ("flyout") for a suggested entity, property, or type — shown by
 : OpenRefine's autocomplete widget on hover. GET /api/reconcile/suggest/flyout?kind=
 : (entity|property|type)&id=...
 :
 : Not part of the 1.0-draft spec (superseded there by the dedicated /preview route for
 : entities; properties/types have no 1.0-draft flyout equivalent at all), but required
 : for 0.2: OpenRefine's own vendored suggest widget (externals/suggest/suggest-4_3a.js)
 : does not follow the 0.2 spec's documented "absence of flyout_service_path means no
 : flyout service" rule — it falls back to its own hardcoded legacy Freebase default
 : (a "/search" sub-path) whenever a suggest config doesn't declare flyout_service_path
 : itself, silently querying (and 404ing against) OUR base URL + "/search" instead of
 : just doing nothing. Declaring an explicit flyout_service_path for every 0.2
 : suggest.{entity,property,type} object is the only way to stop that. Confirmed live:
 : this exact 404 loop is what appeared in the server log immediately after selecting a
 : property in OpenRefine's "Add columns from reconciled values" dialog.
 :
 : The "html" field is embedded by the *client* directly into the page DOM (OpenRefine's
 : own suggest widget does `.html(data.html)`; this project's annotate-editor connector
 : does `container.innerHTML = output` for the sibling /preview route — see
 : ReconciliationService.info() in tei-publisher-components) — so every interpolated
 : name here MUST be escaped. An entity's label is not developer-controlled config the
 : way property/type names are: it's extracted straight from document content (e.g.
 : tei:persName/string()), which anyone with document-edit access (the annotate editor
 : itself, or the "upload" profile) can influence. Confirmed live: an unescaped
 : `<script>` planted in a person's persName came back verbatim in this endpoint's "html"
 : field before this fix. :)
declare function reconc:suggest-flyout($request as map(*)) {
    let $kind := $request?parameters?kind
    let $id := $request?parameters?id
    let $html :=
        switch ($kind)
        case "property" return
            let $prop := reconc:property-by-id($id)
            return if (exists($prop)) then "<p>" || reconc:escape-html($prop?name) || "</p>" else ()
        case "type" return
            let $type := $reconc-config:TYPES?($id)
            return if (exists($type)) then "<p>" || reconc:escape-html($type?name) || "</p>" else ()
        default return
            let $found := reconc:entity-by-id($id)
            return if (exists($found)) then "<p>" || reconc:escape-html(reconc:label($found?entity, $found?type-id)) || "</p>" else ()
    return
        map { "id": $id, "html": ($html, "") [1] }
};

(:~ True if $value is a URL-shaped string that isn't already safe to embed as-is: not a
 : full absolute URL (no "scheme://"), not already app-root-relative (leading "/"), and
 : not one of the special schemes a browser resolves specially rather than against the
 : current page (fragment-only "#...", "mailto:", "tel:", "javascript:", "data:"). Used
 : by reconc:absolutize-links to decide which href/src values actually need rewriting —
 : rewriting an already-safe value would be a no-op at best and wrong at worst (e.g.
 : mangling a "data:image/..." value). :)
declare %private function reconc:is-relative-url($value as xs:string) as xs:boolean {
    not(
        contains($value, "://") or
        starts-with($value, "/") or
        starts-with($value, "#") or
        starts-with($value, "mailto:") or
        starts-with($value, "tel:") or
        starts-with($value, "javascript:") or
        starts-with($value, "data:")
    )
};

(:~ Rewrites every relative href/src found anywhere in $nodes to be absolute against
 : $base. Needed because the preview HTML this module renders does not get consumed the
 : way its own doc comment originally assumed ("meant to be embedded in an iframe", where
 : a same-document relative link would at least resolve consistently against the preview
 : URL itself) — the shipped annotate-editor client instead fetches this HTML and injects
 : it directly into an existing page's DOM via innerHTML (see tei-publisher-components'
 : ReconciliationService.info()), which does NOT parse/honor a <base> tag the way loading
 : a full document would. A relative link like the "registers" profile's own
 : register-overview transform emits (e.g. href="people/kbga-actors-27", correct only
 : when rendered as part of a page already served AT that same path) then resolves
 : against whatever page happens to have the preview injected into it instead — e.g. a
 : preview shown inside a "/sermons/27004.xml" annotation page produced a link to
 : ".../sermons/people/kbga-actors-27" instead of ".../people/kbga-actors-27". Rewriting
 : the markup itself, rather than relying on <base>, is correct regardless of how a
 : client chooses to embed the result. :)
declare %private function reconc:absolutize-links($nodes as node()*, $base as xs:string) as node()* {
    for $n in $nodes
    return
        typeswitch ($n)
            case element() return
                element { node-name($n) } {
                    for $a in $n/@*
                    return
                        if (local-name($a) = ("href", "src") and reconc:is-relative-url($a)) then
                            attribute { node-name($a) } { $base || "/" || $a }
                        else
                            $a,
                    reconc:absolutize-links($n/node(), $base)
                }
            default return $n
};

(:~ Heuristic: does $value look like it points at an image rather than plain text? Used
 : to decide whether a property's value(s) should be rendered as an <img> thumbnail in
 : the default preview instead of as text — there is no way to know this for certain
 : from a bare string alone (a property's "value" extractor returns xs:string*, not a
 : typed/annotated value), so this is deliberately conservative: a "data:image/..." URI,
 : or a URL whose path ends in a common image extension. A property definition can
 : override the guess either way with an explicit "image": true()/false() — see
 : reconc:render-html. :)
declare %private function reconc:looks-like-image($value as xs:string) as xs:boolean {
    starts-with($value, "data:image/") or
    matches($value, "\.(jpe?g|png|gif|svg|webp|bmp|avif)(\?[^#]*)?(#.*)?$", "i")
};

(:~ Renders the preview/view HTML for a matched entity: the type's own "preview"
 : function-item if configured (full control — used as-is, not post-processed), otherwise
 : the app's ODD web-transform pipeline (the same one the "registers" profile itself
 : uses) in the type's configured "preview-mode" (default "register-overview"), followed
 : by every configured property that actually has a value for this entity — the same
 : properties /extend and /extend/propose already expose, so nothing needs configuring
 : twice. A property whose value(s) look like an image (see reconc:looks-like-image, or
 : an explicit "image": true()/false() on the property definition to force the decision)
 : renders as a thumbnail instead of text. :)
declare %private function reconc:render-html($request as map(*), $found as map(*)?) as item()* {
    if (empty($found)) then
        <html><head><meta charset="UTF-8"/></head><body><p>Entity not found.</p></body></html>
    else
        let $entity := $found?entity
        let $type-def := $reconc-config:TYPES?($found?type-id)
        return
            if (exists($type-def?preview)) then
                ($type-def?preview)($entity)
            else
                let $odd := head(($request?parameters?odd, $config:default-odd))
                let $mode := head(($type-def?preview-mode, "register-overview"))
                let $prop-rows :=
                    for $p in reconc:properties-for-type($found?type-id)
                    let $extractor := reconc-cond:resolve-extractor($p?value)
                    let $values :=
                        if (exists($extractor)) then
                            for $v in $extractor($entity)
                            let $s := normalize-space(string($v))
                            where $s != ""
                            return $s
                        else
                            ()
                    where exists($values)
                    let $is-image := ($p?image, reconc:looks-like-image($values[1]))[1]
                    return
                        <tr>
                            <th style="text-align:left; vertical-align:top; padding-right:0.5em;">{$p?name}</th>
                            <td>{
                                if ($is-image) then
                                    for $v in $values return <img src="{$v}" alt="{$p?name}" style="max-width:100%; max-height:8em;"/>
                                else
                                    string-join($values, "; ")
                            }</td>
                        </tr>
                let $body :=
                    <div class="reconcile-preview">
                    { ($pm-config:web-transform)($entity, map { "mode": $mode }, $odd) }
                    { if (exists($prop-rows)) then <table class="reconcile-preview-properties">{$prop-rows}</table> else () }
                    </div>
                return
                    <html>
                        <head><meta charset="UTF-8"/></head>
                        <body style="font-family: sans-serif; margin: 0.5em;">
                        { reconc:absolutize-links($body, reconc:site-root($request)) }
                        </body>
                    </html>
};

(:~
 : HTML preview for embedding in an iframe (manifest.preview).
 : GET /api/reconcile/preview?id=...
 :)
declare function reconc:preview($request as map(*)) {
    let $id := $request?parameters?id
    let $found := reconc:entity-by-id($id)
    return
        router:response(200, "text/html", reconc:render-html($request, $found))
};

(:~
 : Entity view (manifest.view): GET /api/reconcile/entity/{id}
 :
 : The entity's type "view" config (see reconcile-config.xql) decides what happens:
 :  - a function item is called directly for full control over the response;
 :  - an xs:string (a "registers" browse-page name) redirects there, but only if
 :    the "registers" profile is actually installed in this app — otherwise falls
 :    through to the same ODD-based preview rendering used when no "view" is
 :    configured at all. This is what lets the shipped defaults (which set
 :    "view": "people"/"places") work whether or not "registers" happens to be
 :    part of the app: reconcile itself only depends on "base10".
 :)
declare function reconc:entity($request as map(*)) {
    let $id := $request?parameters?id
    let $found := reconc:entity-by-id($id)
    return
        if (empty($found)) then
            error($errors:NOT_FOUND, "No reconciled entity with id " || $id)
        else
            let $view := $reconc-config:TYPES?($found?type-id)?view
            return
                if ($view instance of function(*)) then
                    $view($id, $found, $request)
                else if (exists($view) and reconc-config:profile-installed("registers")) then
                    router:response(303, (), (), map { "Location": reconc:site-root($request) || "/" || $view || "/" || $id })
                else
                    router:response(200, "text/html", reconc:render-html($request, $found))
};

(:~ Looks up a property definition by id across all types (property ids are assumed
 : unique across the configured type registry). :)
declare %private function reconc:property-by-id($id as xs:string?) as map(*)? {
    if (empty($id)) then
        ()
    else
        head(reconc:properties-for-type(())[?id = $id])
};

(:~ Builds a data-extension response for the given query, shaped per protocol version
 : ("rows" is an array of {id, properties} in 1.0-draft, an id-keyed object of
 : property-id-keyed value arrays in 0.2). :)
declare %private function reconc:extend-response($query as map(*), $version as xs:string?) as map(*) {
    let $ids := $query?ids?*
    let $properties := $query?properties?*
    return
        if (count($ids) > $reconc-config:MAX_EXTEND_IDS) then
            error($errors:BAD_REQUEST, "Too many ids: " || count($ids) || " (max " || $reconc-config:MAX_EXTEND_IDS || ")")
        else if (count($properties) > $reconc-config:MAX_EXTEND_PROPERTIES) then
            error($errors:BAD_REQUEST, "Too many properties: " || count($properties) || " (max " || $reconc-config:MAX_EXTEND_PROPERTIES || ")")
        else
            reconc:extend-response-unchecked($ids, $properties, $version)
};

declare %private function reconc:extend-response-unchecked($ids as xs:string*, $properties as item()*, $version as xs:string?) as map(*) {
    let $meta := array {
        for $p in $properties
        let $prop-def := reconc:property-by-id($p?id)
        return map { "id": $p?id, "name": ($prop-def?name, $p?id)[1] }
    }
    let $value-for := function($id as xs:string, $prop-id as xs:string) as xs:string* {
        let $found := reconc:entity-by-id($id)
        (: Scoped to the entity's own type, not reconc:property-by-id's global lookup:
         : property ids only need to be unique *within* a type (see reconcile-config.xql's
         : doc comment) — the shipped defaults now reuse "gnd" for both "person" and
         : "work", each with a different extractor, so picking a property definition
         : without knowing which type the entity actually is would silently apply the
         : wrong one whenever two types share a property id. :)
        let $prop-def := if (exists($found)) then head(reconc:properties-for-type($found?type-id)[?id = $prop-id]) else ()
        return
            if (exists($found) and exists($prop-def)) then
                let $extractor := reconc-cond:resolve-extractor($prop-def?value)
                return
                    for $v in $extractor($found?entity)
                    let $s := string($v)
                    where $s != ""
                    return $s
            else
                ()
    }
    return
        if ($version = "0.2") then
            map {
                "meta": $meta,
                "rows": map:merge(
                    for $id in $ids
                    return
                        map:entry($id, map:merge(
                            for $p in $properties
                            return map:entry($p?id, array { for $v in $value-for($id, $p?id) return map { "str": $v } })
                        ))
                )
            }
        else
            map {
                "meta": $meta,
                "rows": array {
                    for $id in $ids
                    return
                        map {
                            "id": $id,
                            "properties": array {
                                for $p in $properties
                                return
                                    map {
                                        "id": $p?id,
                                        "values": array { for $v in $value-for($id, $p?id) return map { "str": $v } }
                                    }
                            }
                        }
                }
            }
};

(:~
 : Data extension: fetch property values for a batch of entity ids.
 : POST /api/reconcile/extend (1.0-draft canonical path). The classic GET
 : "<endpoint>?extend=..." convention some clients (incl. the local test bench) still
 : use is handled directly in reconc:manifest.
 :)
declare function reconc:extend($request as map(*)) {
    reconc:extend-response($request?body, $request?parameters?version)
};

(:~
 : Data extension property proposal: suggest properties fetchable for a given type.
 : GET /api/reconcile/extend/propose?type=...&limit=...
 :)
declare function reconc:extend-propose($request as map(*)) {
    let $type := $request?parameters?type
    let $limit := reconc:safe-limit($request?parameters?limit, 20)
    let $props := subsequence(reconc:properties-for-type($type), 1, max(($limit, 0)))
    return
        map:merge((
            map {
                "properties": array { for $p in $props return map { "id": $p?id, "name": $p?name } },
                "limit": $limit
            },
            if (exists($type)) then map { "type": $type } else ()
        ))
};
