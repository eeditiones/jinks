xquery version "3.1";

(:~
 : Reconciliation type registry — the single place to add, remove, or customize what
 : "kinds of things" this service reconciles. Sensible defaults ship here for the
 : typical case (person/place/organization/work read from the app's "registers"
 : collection — see $config:register-root/$config:register-map in base10's own
 : config.xqm; this is a base10-level convention, not specific to the "registers"
 : profile). This profile only depends on "base10" — installing the "registers"
 : profile too is optional: if present, its browse pages are used for
 : GET /api/reconcile/entity/{id} (see "view" below); if not, a built-in ODD-based
 : preview is used instead, with identical defaults either way. Edit this file
 : directly to point at different content, a different vocabulary, or an entirely
 : different scoring algorithm.
 :
 : Jinks tracks this file like any other: a fresh `jinks create` copies these
 : defaults in; if you edit it locally afterwards, a later `jinks update` will
 : detect the change and report a *conflict* instead of silently overwriting your
 : customization (see reconcile/doc/README.md for details).
 :
 : Each entry in $reconc-config:TYPES is a map:
 :   name          - display name, used in the manifest and suggest/type
 :   view          - (optional) either:
 :                     - an xs:string naming a "registers" profile browse page (e.g.
 :                       "people") to redirect to for GET /api/reconcile/entity/{id}.
 :                       Only used if the "registers" profile is actually installed
 :                       in *this* app (checked at request time via
 :                       reconc-config:profile-installed("registers"), below) — if
 :                       it isn't, or no "view" is given at all, the default
 :                       ODD-based preview renderer is used instead (see
 :                       "preview"/"preview-mode"). This is what makes the shipped
 :                       defaults work identically whether or not "registers" is
 :                       part of the app: reconcile itself only depends on "base10".
 :                     - a function($id as xs:string, $found as map(*), $request as
 :                       map(*)) as item()* for full control over the
 :                       /entity/{id} response — e.g. redirect somewhere else
 :                       entirely, or render something bespoke. Build the response
 :                       yourself with router:response(...); reconc-config:profile-installed(...)
 :                       is available if your override wants the same
 :                       is-this-profile-present check.
 :   entities      - function() as element()* — returns every candidate entity node
 :                   for this type. Always a function (not an XPath string): the
 :                   context — which collection, relative to what — is inherently
 :                   ambiguous for a bare selection XPath, so a closure is both
 :                   clearer and no more work to write.
 :   label         - the human-readable label for a matched entity: what's returned
 :                   as candidate.name and used for /entity/{id}'s "view" redirect.
 :                   Either a function($entity as element()) as xs:string, or an
 :                   xs:string containing an XPath expression evaluated with the
 :                   entity as context (e.g. ".//tei:persName[@type='main'][1]") —
 :                   see reconc:resolve-extractor in reconcile-api.xql.
 :   labels        - (optional) every name *variant* worth matching against for this
 :                   type — function($entity as element()) as xs:string*, or an
 :                   xs:string XPath (same rules as "label", but expected to select
 :                   more than one node). Scoring uses the best match across all of
 :                   them; the response's displayed name still always comes from the
 :                   single "label" above. Omit if a type only ever has one name form
 :                   (matching then just uses "label" alone, unchanged) — not every
 :                   type benefits: e.g. this profile's own "work"/"organization"
 :                   defaults don't set it, because the demo data backing them never
 :                   has more than one title/name to begin with.
 :   fulltext-search - (optional) function($query as xs:string) as element()* — like
 :                   "entities", but pre-filtered by $query against a Lucene text
 :                   field already indexed in the app's collection.xconf (e.g.
 :                   "name"), so a large collection doesn't need scoring entity by
 :                   entity. This has to be its own closure rather than reconc:candidates
 :                   filtering "entities"'s result by ft:query() afterwards: eXist
 :                   only rewrites ft:query() into an actual index lookup when it's
 :                   a predicate *inside* the same path expression doing the
 :                   collection traversal — applying it to an already-materialized
 :                   node sequence still runs, but ~300x slower in testing against
 :                   this project's demo data (955ms vs. 3ms for the same 33-entity
 :                   collection), because it loses the index and falls back to a
 :                   per-node check. So write the ft:query() predicate directly into
 :                   your own path expression, the same way "entities" is written —
 :                   reconc-fulltext:fuzzy-query($field, $query) (imported below)
 :                   builds a fuzzy ("~") Lucene query string for you; see the
 :                   shipped "person"/"place"/"work" defaults for the exact pattern
 :                   to copy. Leaving this field unset (the safe default) falls back
 :                   to scoring every entity individually via "entities" — slower,
 :                   but always correct regardless of indexing, so this is purely
 :                   opt-in. "organization" is deliberately left unset: its tei:org
 :                   elements aren't indexed by the shipped collection.xconf at all.
 :   preview-mode  - (optional) the ODD web-transform mode used to render this
 :                   type's default HTML preview (GET /api/reconcile/preview and the
 :                   /entity/{id} fallback). Defaults to "register-overview" — the
 :                   same mode the "registers" profile itself uses. Ignored if
 :                   "preview" (below) is given.
 :   preview       - (optional) function($entity as element()) as node() — fully
 :                   overrides preview rendering for this type instead of using the
 :                   ODD transform.
 :   properties    - map of property-id -> map { name, value }, where "value" is
 :                   either a function($entity as element()) as xs:string*, or an
 :                   xs:string XPath (same rules as "label"). Drives
 :                   /suggest/property, /extend and /extend/propose.
 :)
module namespace reconc-config = "http://teipublisher.com/api/reconcile/config";

import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace reconc-score = "http://teipublisher.com/api/reconcile/scoring" at "reconcile-scoring.xql";
import module namespace reconc-fulltext = "http://teipublisher.com/api/reconcile/fulltext" at "reconcile-fulltext.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~ True if the named Jinks profile was extended into this application, per the
 : generator's merged context.json "profiles" list (written once at app-generation
 : time by every `jinks create`/`jinks update` — see generator:save-config in
 : tei-publisher-jinks/modules/generator.xql). This is the same condition that
 : determines whether that profile's own routes/pages actually exist in this app,
 : so it's a reliable way to check "would a link to profile X's UI actually work"
 : rather than assuming X is present. Used below to make the shipped "view"
 : defaults degrade gracefully when "registers" isn't installed; also useful from
 : a custom "view" (or other) override that wants the same check. :)
declare function reconc-config:profile-installed($name as xs:string) as xs:boolean {
    let $ctx := json-doc($config:app-root || "/context.json")
    return
        $name = $ctx?profiles?*
};

(:~ Converts a "gnd-<id>"-shaped local identifier (the convention this demo data
 : uses both for some persons' @xml:id, e.g. "gnd-119442086", and for works'
 : tei:idno[@type='GND'], e.g. "gnd-4211173-0") into a real, resolvable GND URI.
 : Returns the empty sequence for anything not in that shape (most entities aren't
 : GND-sourced at all, which is normal — extend properties are allowed to be
 : absent). Shared by the "person" and "work" defaults below. :)
declare function reconc-config:gnd-uri-from-id($id as xs:string?) as xs:string? {
    if (exists($id) and starts-with($id, "gnd-")) then
        "https://d-nb.info/gnd/" || substring-after($id, "gnd-")
    else
        ()
};

declare variable $reconc-config:TYPES := map {
    "person": map {
        "name": "Person",
        "view": "people",
        "entities": function() as element()* {
            collection($config:register-root)/id($config:register-map?person?id)//tei:person[@xml:id]
        },
        "label": function($e as element()) as xs:string {
            normalize-space(($e/tei:persName[@type = "main"], $e/tei:persName, $e)[1])
        },
        "labels": function($e as element()) as xs:string* {
            $e/tei:persName/string()
        },
        "fulltext-search": function($query as xs:string) as element()* {
            collection($config:register-root)/id($config:register-map?person?id)//tei:person[
                @xml:id and ft:query(., reconc-fulltext:fuzzy-query("name", $query), map { "leading-wildcard": "yes", "filter-rewrite": "yes" })
            ]
        },
        "preview-mode": "register-overview",
        "properties": map {
            "gender": map { "name": "Gender", "value": function($e as element()) as xs:string* { normalize-space($e/tei:gender[1]) } },
            "note": map { "name": "Biographical note", "value": function($e as element()) as xs:string* { normalize-space($e/tei:note[1]) } },
            "occupation": map { "name": "Occupation", "value": function($e as element()) as xs:string* { $e/tei:occupation/string() } },
            "gnd": map { "name": "GND identifier", "value": function($e as element()) as xs:string* { reconc-config:gnd-uri-from-id($e/@xml:id/string()) } },
            (: Worked example of a property computed from OUTSIDE the entity itself — not
             : extracted from the register record, but derived by querying the document
             : corpus for every place this person is actually referenced (persName/@key
             : matching this entity's own @xml:id, the convention this demo's own TEI
             : documents already use) and aggregating over the results. A property's
             : "value" is always a plain function($entity as element()) as xs:string* —
             : nothing about the reconciliation protocol restricts it to reading the
             : entity's own subtree; it runs with full XQuery/collection access like any
             : other function in this module, so anything expressible in XQuery (a join,
             : an aggregate, a call to an external service) is fair game here. Kept
             : cheap deliberately: sums document-level title lengths already in memory
             : rather than anything requiring its own index. :)
            "avg-title-length": map {
                "name": "Average title length of documents mentioning this person",
                "value": function($e as element()) as xs:string* {
                    let $id := $e/@xml:id/string()
                    let $lengths :=
                        for $doc in collection($config:data-root)//tei:persName[@key = $id]/root()
                        let $title := $doc//tei:titleStmt/tei:title[1]
                        where exists($title)
                        return string-length(normalize-space($title))
                    return if (exists($lengths)) then string(avg($lengths)) else ()
                }
            },
            (: Illustrative placeholder, not real biographical data — a generic silhouette
             : icon (a self-contained "data:image/svg+xml;base64,..." value, no external
             : request involved), demonstrating that reconc:looks-like-image in
             : reconcile-api.xql auto-detects an image-shaped property value and renders it
             : as a thumbnail in the default /preview instead of as plain text — no "image"
             : flag set here deliberately, to prove the heuristic itself does the work
             : rather than an explicit override. A real deployment would point this at an
             : actual portrait URL instead (a GND/Wikidata depicting-image field, a
             : digitized-archive scan, etc.); set "image": false() on a property here to
             : opt back out if a real URL value is ever misdetected as an image. :)
            "portrait": map {
                "name": "Portrait",
                "value": function($e as element()) as xs:string* {
                    "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI4MCIgaGVpZ2h0PSI4MCIgdmlld0JveD0iMCAwIDgwIDgwIj48Y2lyY2xlIGN4PSI0MCIgY3k9IjQwIiByPSI0MCIgZmlsbD0iI2NjYyIvPjxjaXJjbGUgY3g9IjQwIiBjeT0iMzAiIHI9IjE0IiBmaWxsPSIjZmZmIi8+PHBhdGggZD0iTTEyIDcwYzQtMTggMjAtMjYgMjgtMjZzMjQgOCAyOCAyNiIgZmlsbD0iI2ZmZiIvPjwvc3ZnPg=="
                }
            }
        }
    },
    "place": map {
        "name": "Place",
        "view": "places",
        "entities": function() as element()* {
            collection($config:register-root)/id($config:register-map?place?id)//tei:place[@xml:id]
        },
        "label": function($e as element()) as xs:string {
            normalize-space(($e/tei:placeName[@type = "main"], $e/tei:placeName, $e)[1])
        },
        "labels": function($e as element()) as xs:string* {
            $e/tei:placeName/string()
        },
        "fulltext-search": function($query as xs:string) as element()* {
            collection($config:register-root)/id($config:register-map?place?id)//tei:place[
                @xml:id and ft:query(., reconc-fulltext:fuzzy-query("name", $query), map { "leading-wildcard": "yes", "filter-rewrite": "yes" })
            ]
        },
        "preview-mode": "register-overview",
        "properties": map {
            "geo": map { "name": "Coordinates", "value": function($e as element()) as xs:string* { normalize-space($e/tei:location/tei:geo[1]) } },
            "type": map { "name": "Place type", "value": function($e as element()) as xs:string* { $e/@type/string() } },
            "geonames": map { "name": "GeoNames identifier", "value": function($e as element()) as xs:string* { $e/tei:ptr[@type = "geonames"]/@target/string() } },
            "wikidata": map { "name": "Wikidata identifier", "value": function($e as element()) as xs:string* { $e/tei:ptr[@type = "wikidata"]/@target/string() } }
        }
    },
    "organization": map {
        "name": "Organization",
        "entities": function() as element()* {
            collection($config:register-root)/id($config:register-map?organization?id)//tei:org[@xml:id]
        },
        "label": function($e as element()) as xs:string {
            normalize-space(($e/tei:orgName[@type = "main"], $e/tei:orgName, $e)[1])
        },
        "preview-mode": "register-overview",
        "properties": map {}
    },
    "work": map {
        "name": "Work",
        "entities": function() as element()* {
            collection($config:register-root)/id($config:register-map?work?id)//tei:bibl[@xml:id]
        },
        "label": function($e as element()) as xs:string {
            normalize-space(($e/tei:title[@type = "main"], $e/tei:title, $e)[1])
        },
        "fulltext-search": function($query as xs:string) as element()* {
            collection($config:register-root)/id($config:register-map?work?id)//tei:bibl[
                @xml:id and ft:query(., reconc-fulltext:fuzzy-query("name", $query), map { "leading-wildcard": "yes", "filter-rewrite": "yes" })
            ]
        },
        "preview-mode": "register-overview",
        "properties": map {
            "author": map { "name": "Author", "value": function($e as element()) as xs:string* { normalize-space($e/tei:author[1]) } },
            "gnd": map { "name": "GND identifier", "value": function($e as element()) as xs:string* { reconc-config:gnd-uri-from-id($e/tei:idno[@type = "GND"]/string()) } }
        }
    }
};

(:~ Matching/ranking function: given a candidate's label and the query string,
 : return a score between 0 (no match) and 100 (perfect match). Point this at your
 : own function item to change the algorithm (fuzzy matching, external NER-based
 : scoring, weighting by property matches, etc.) — see reconc-score:default for the
 : signature to match. :)
declare variable $reconc-config:SCORE := reconc-score:default#2;

(:~ Request-size caps (see reconcile-api.xql for exactly where each is applied).
 : Two different enforcement styles are used, deliberately:
 :  - MAX_BATCH_SIZE / MAX_EXTEND_IDS / MAX_EXTEND_PROPERTIES are hard limits: a
 :    request that exceeds one is rejected outright (HTTP 400), never silently
 :    truncated. Reconciliation batch responses are strictly *positional*
 :    ("results[i]" corresponds to "queries[i]"; /extend's "rows" must cover every
 :    requested id/property) — silently dropping entries would silently corrupt
 :    that correspondence for the caller, which is worse than an explicit,
 :    actionable error.
 :  - MAX_LIMIT is a soft cap: an over-large "limit" parameter is silently clamped
 :    down to it, not rejected — asking for "too many" results isn't invalid, just
 :    excessive, and clamping is the more client-friendly, conventional behavior.
 : Raise or lower these for your own deployment's expected batch sizes and
 : available resources; there is no protocol-mandated value for any of them. :)
declare variable $reconc-config:MAX_BATCH_SIZE := 500;
declare variable $reconc-config:MAX_LIMIT := 1000;
declare variable $reconc-config:MAX_EXTEND_IDS := 500;
declare variable $reconc-config:MAX_EXTEND_PROPERTIES := 100;
