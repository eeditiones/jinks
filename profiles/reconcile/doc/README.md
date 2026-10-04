# Reconciliation Service API — customizing the entity model

This profile implements the [OpenRefine Reconciliation Service API](https://reconciliation-api.github.io/specs/)
(0.2 and 1.0-draft) as a generic HTTP layer on top of a **configurable type registry**. Everything
domain-specific — what counts as a "person"/"place"/"organization", how a label is extracted, which
properties are fetchable, how a preview renders, how candidates are ranked — lives in one file,
`modules/reconcile-config.xql`, not in the HTTP handlers (`modules/reconcile-api.xql`).

## What ships by default

`reconcile-config.xql` ships defaults for four types — `person`, `place`, `organization`, `work` —
read from the app's `registers` collection (`$config:register-root`/`$config:register-map` — a
**base10** convention, the same one the `annotate` entity editors write to). Matching/ranking uses
a string-similarity function with a typo-tolerant fallback tier, `reconc-score:default` in
`modules/reconcile-scoring.xql` (see "Matching / ranking" below); `person`/`place`/`work` also
pre-filter candidates through a Lucene full-text index for speed on larger collections (see
`"fulltext-search"` below) — `organization` doesn't, since it has no real data or index in this
demo app to validate one against. `person`/`place` additionally match against every name *variant*
an entity has, not just its primary display name (see `"labels"` below), and all four types expose
a few real external-identifier extend properties (GND for person/work, GeoNames/Wikidata for place)
alongside their original ones — which, in turn, can also be used as *match* conditions in a
reconciliation query, not just fetched via `/extend` (see "Matching on more than just a name"
below).

This profile only `depends` on `base10`. The **`registers` profile** (the one that adds the
`/people`, `/places`, ... browse pages) is entirely optional: if it's installed, `GET
/api/reconcile/entity/{id}` redirects to its browse page for types that configure a `"view"`; if
it isn't, the same endpoint transparently falls back to a built-in ODD-based preview instead — see
`"view"` below. There is no scenario where a shipped default requires `registers` to be present.

## Customizing it

Edit `modules/reconcile-config.xql` directly in your app checkout. It's an ordinary, `jinks
update`-tracked file: a fresh `jinks create` copies these defaults in, and if you edit the file
afterwards, a later `jinks update` will detect the change and report a **conflict** — the file is
left untouched, not silently overwritten. (Choosing to "resolve" that conflict via `jinks-cli`
means *accepting the profile's upstream defaults and discarding your edit* — there's no "keep mine
and stop nagging" option in Jinks today, so just leave the conflict unresolved and it'll keep being
reported, harmlessly, on every future update.)

### Adding/removing/redefining a type

Each entry in `$reconc-config:TYPES` is a map:

```xquery
"person": map {
    "name": "Person",                    (: display name, manifest + suggest/type :)
    "view": "people",                    (: optional: registers browse-page name for /entity/{id} — see below :)
    "entities": function() as element()* {
        collection($config:register-root)/id($config:register-map?person?id)//tei:person[@xml:id]
    },
    "label": function($e as element()) as xs:string { ... },   (: OR an xs:string XPath — see below :)
    "labels": function($e as element()) as xs:string* { ... }, (: optional: every name variant to match against — see below :)
    "fulltext-search": function($query as xs:string) as element()* { ... },  (: optional: Lucene pre-filter — see below :)
    "preview-mode": "register-overview", (: optional: ODD web-transform mode for the default preview :)
    "preview": function($e as element()) as node() { ... },    (: optional: full override of preview rendering :)
    "properties": map {
        "gender": map { "name": "Gender", "value": function($e as element()) as xs:string* { ... } }
    }
}
```

To point at completely different content — a different collection, a non-register vocabulary, a
different TEI element altogether — just write a different `"entities"` closure; nothing else in
the profile needs to know or care. To drop a type, remove its entry; to add one, add a new key.
Property ids only need to be unique *within* a type's `properties` map, not globally — the shipped
defaults actually rely on this (both `"person"` and `"work"` have a `"gnd"` property, each with its
own extractor); `/extend` always resolves a property against the *matched entity's own type*, never
just the first type that happens to define a property with that id.

`"entities"` is always a zero-argument function item (never a bare XPath string) — the context for
a *selection* XPath (which collection? relative to what?) is inherently ambiguous, so a closure is
both clearer and no more work to write.

### Function items vs. XPath strings for `"label"` and property `"value"`

Both are accepted, and mean the same thing: "given the matched entity node, produce the label /
property value(s)". A function item is called directly. An `xs:string` is treated as a **relative**
XPath expression and evaluated dynamically against the entity (e.g. `".//tei:persName[@type='main'][1]"`,
`"@type"`, or just `"."` to use the whole entity's text).

```xquery
"label": ".//tei:persName[@type='main'][1]"
```

is equivalent to

```xquery
"label": function($e as element()) as xs:string {
    normalize-space($e/tei:persName[@type = "main"][1])
}
```

**Tradeoffs, so you can choose deliberately:**

- **XPath strings** are quick to write for anyone who knows XPath but not XQuery function syntax,
  and read declaratively in the config file.
- **Function items** are what the shipped defaults use, and are the better choice whenever you need
  more than a single path expression: combining multiple fields, falling back through several
  candidates, calling another function, cross-referencing other data. They're also faster (compiled
  once, not re-evaluated as a string each call) and don't widen the trust boundary — see below.
- Dynamic evaluation (`util:eval`, which is what an XPath string ultimately goes through) runs with
  **the full permissions of the calling module** — it is not a sandboxed XPath-only evaluator, it's
  full XQuery 3.1 with access to anything importable from `reconcile-api.xql`'s own static context
  (though that module deliberately keeps its imports minimal). This is a non-issue if only a trusted
  app developer/administrator ever edits `reconcile-config.xql` (the normal case — it's a profile
  source file, not end-user input), but is worth knowing if you ever consider exposing this file to
  a less-trusted editor.

### `"view"`: redirecting to a browse page, safely

`"view"` controls what `GET /api/reconcile/entity/{id}` does for a type, and accepts either:

- an `xs:string` naming a `registers`-profile browse page (e.g. `"people"`) — but it's only
  actually used if the `registers` profile is confirmed installed in *this* app
  (`reconc-config:profile-installed("registers")`, checked against the generator's own
  `context.json` at request time, not assumed); otherwise the endpoint falls through to the same
  default preview rendering used when no `"view"` is set at all. This is what lets the shipped
  `"view": "people"`/`"places"` defaults work identically whether or not you happen to have
  `registers` installed — you never need to remove them yourself.
- a `function($id as xs:string, $found as map(*), $request as map(*)) as item()*` for full control
  — build the response yourself with `router:response(...)` (redirect somewhere else entirely,
  render something bespoke, whatever you need). `reconc-config:profile-installed(...)` is public,
  so a custom override can reuse the same "is this other profile actually here" check.
- omitted entirely — always uses the default preview rendering (same as the string case when
  `registers` isn't installed).

```xquery
"view": function($id as xs:string, $found as map(*), $request as map(*)) as item()* {
    router:response(303, (), (), map { "Location": "https://example.org/persons/" || $id })
}
```

### `"labels"`: matching every name variant, not just the display name

Real entities often have more than one name worth matching against — historical spellings,
abbreviations, sort forms — even though only one of them should ever be *shown*. `"labels"` is the
plural sibling of `"label"`: same rules (function item or XPath string, but expected to select more
than one node), used only for **scoring**, never for display. A query is scored against every
variant and the best match wins; `candidate.name` in the response always comes from `"label"`
alone, untouched.

```xquery
"labels": function($e as element()) as xs:string* {
    $e/tei:persName/string()   (: every persName, not just the "main" one "label" prefers :)
}
```

Omit it for a type that only ever has one name form — matching then just uses `"label"` by itself,
identical to before `"labels"` existed. That's why the shipped `"organization"`/`"work"` defaults
don't set it: this demo app's data for those two never has more than one name/title to begin with,
so there'd be nothing to gain.

### `"fulltext-search"`: fast candidate pre-filtering with fuzzy recall

For a type with more than a handful of entities, scoring every single one on every query gets slow.
`"fulltext-search"` is an optional, faster alternative to `"entities"` for the *matching* path (only
— `"entities"` itself is still used everywhere else, e.g. `/suggest/type`'s candidate counts):
`function($query as xs:string) as element()*`, expected to pre-filter down to plausible candidates
using a Lucene full-text index already declared in the app's `collection.xconf`.

```xquery
"fulltext-search": function($query as xs:string) as element()* {
    collection($config:register-root)/id($config:register-map?person?id)//tei:person[
        @xml:id and ft:query(., reconc-fulltext:fuzzy-query("name", $query), map { "leading-wildcard": "yes", "filter-rewrite": "yes" })
    ]
}
```

`reconc-fulltext:fuzzy-query($field, $query)` (from the small shared `modules/reconcile-fulltext.xql`,
already imported by this file) builds a Lucene query string with the classic `~` fuzzy operator on
every query token, so a typo still matches. **The `ft:query(...)` predicate has to be written
directly inside your own path expression, exactly like the example above** — it cannot be applied
afterwards as a filter on `("entities")()`'s result. eXist only rewrites `ft:query()` into an actual
index lookup when it's a predicate *inside* the same path expression doing the collection traversal;
applied to an already-materialized node sequence it still runs, just roughly 300x slower in testing
against this project's own demo data (955ms vs. 3ms for the same 33-entity collection) — the whole
point of this field is defeated if it's not written this way. Leaving `"fulltext-search"` unset (the
safe default) falls back to scoring every entity from `"entities"` individually — slower for a large
collection, but always correct regardless of what is or isn't indexed, so this is purely opt-in.
Only set it for a type whose element is genuinely covered by `collection.xconf` — the shipped
`person`/`place`/`work` defaults all reuse the same `"name"` field the `registers` profile itself
already searches; `"organization"` deliberately leaves it unset, since its `tei:org` elements aren't
indexed at all in the shipped `collection.xconf`.

### Matching / ranking

```xquery
declare variable $reconc-config:SCORE := reconc-score:default#2;
```

Point this at any `function($label as xs:string?, $query as xs:string?) as xs:double` — an external
NER/embedding-based similarity service, weighting by which properties also matched, whatever you
need. `reconc-score:default` in `modules/reconcile-scoring.xql` is public and composable, so you can
also wrap it (e.g. "call the default, then add a language-match boost") rather than writing one from
scratch. It already includes a typo-tolerant fallback tier: exact match scores 100, substring
containment and token overlap score proportionally, and — only once those all fail, and only for
tokens at least 4 characters with an edit distance of at most 2 — a hand-rolled Levenshtein-based
similarity kicks in, compared **token by token** rather than as whole strings (a typo in one word of
a multi-word name like "Goethe, Johann Wolfgang von" would rarely be within edit distance 2 of the
*whole* string, but easily is of just the one mistyped word). This fuzzy tier is what makes
`"fulltext-search"`'s Lucene-level fuzzy recall actually useful: without it, a fuzzy-matched
candidate would still score 0 and get silently dropped by `reconc:candidates`.

### Matching on more than just a name

A reconciliation query isn't always just a name. Both spec versions let a client also send
*property* conditions (disambiguate/refine candidates using another known value, e.g. "and gender
is male") and 1.0-draft additionally allows *id* conditions (match directly against a known entity
id) — and a query can legally have **no name condition at all**, reconciling purely by a known
property value (the spec's own example: reconciling by a `uid` property with no name text
whatsoever). This is exactly the mechanism OpenRefine's "reconcile more columns as properties"
feature relies on. No new config is needed for this — every existing `"properties"` entry (the same
ones already driving `/extend`) doubles as a match condition input, since its `"value"` extractor is
exactly what's needed to read a candidate's actual value and compare it against what the client
asked for.

```json
{
  "conditions": [
    { "matchType": "name", "propertyValue": "Goethe" },
    { "matchType": "property", "propertyId": "gender", "propertyValue": "male", "required": true, "matchQualifier": "ExactMatch" }
  ]
}
```

How a condition affects a candidate:

- **`required: true`** (1.0-draft only; every 0.2 property condition is always optional) — a
  candidate that doesn't satisfy this condition is dropped entirely, regardless of its name score or
  any other condition. **`required: false`/absent** — a matching condition adds a flat score boost
  (capped at 100 total) instead; a non-matching optional condition simply doesn't boost, it never
  excludes.
- **`matchQualifier`** decides how a value is compared: `"ExactMatch"` — exact string equality;
  `"WildcardMatch"` — a glob pattern, `*` standing for any run of characters (e.g. `"Politik*"`);
  anything else, including no qualifier at all (always the case for 0.2), falls back to a
  case-insensitive exact-or-substring match — the same "good enough default" spirit as the name
  scorer's non-fuzzy tiers.
- **`matchQuantifier`** (1.0-draft only, when `propertyValue` is an array of values) — `"any"`: at
  least one of them has to match; `"all"`: every one of them has to; `"none"`: none of them may.
  Defaults to `"any"`.
- A **`matchType: "id"`** condition looks the requested id(s) up directly (`reconc:entity-by-id`) —
  no name or property scan needed — and scores 100 if found, before any property conditions are
  applied on top.
- A query with only property conditions (no name, no id) is answered with a full scan of the
  applicable type(s) — there's no index over arbitrary properties, only over the name field (see
  `"fulltext-search"` above) — so this is correct but not fast for a large collection.

This logic lives in `modules/reconcile-conditions.xql` (the `reconc-cond:normalize-1.0`/
`normalize-0.2`/`evaluate`/`matches-value` functions), not `reconcile-config.xql` — there is nothing
to configure here beyond the `"properties"` you've likely already defined for `/extend`. A few
things this deliberately does *not* attempt: `matchQuantifier`/`required` on an `"id"` condition
(id lookups always mean "any of these ids"); 0.2's `type_strict: "all"` (moot given this profile's
one-type-per-entity model — no candidate could ever belong to more than one type); `lang`/`dir`
-scoped conditions (evaluated language-agnostically regardless); and the boost amount is a flat,
hardcoded constant per matched optional condition, not proportional to match quality or
configurable — good enough to make required filtering and property-only queries genuinely useful,
not a tuned scoring model.

### Preview rendering

By default, `/preview` and the `/entity/{id}` fallback (used when a type has no `"view"` page) run
the entity through the app's own ODD transformation pipeline — the same `pm-config:web-transform`
call the `registers` profile itself uses — in the type's `"preview-mode"` (default
`"register-overview"`). Set a different `"preview-mode"` string to reuse another existing ODD mode,
or a `"preview"` function item (`function($entity as element()) as node()`) to fully replace
rendering for that type. No other endpoint needs extra configuration for a custom type: manifest,
`/suggest/*`, and `/extend`/`/extend/propose` all derive automatically from `$reconc-config:TYPES`.

### Batch requests and repeated work

A single `POST /api/reconcile` request can carry many queries at once. For any type *without*
`"fulltext-search"` (where the only way to find candidates is scoring every entity), `reconc:
reconcile-1.0`/`reconc:reconcile-0.2` precompute that type's entities/labels once per *request*
rather than once per *query* — invisible from the config side, nothing to opt into, but worth
knowing if you're reading `reconcile-api.xql`'s `reconc:candidate-pool`/`reconc:candidates`. Types
*with* `"fulltext-search"` don't need this: `ft:query()` is already a cheap, indexed, per-query-text
lookup, so there's nothing to usefully precompute ahead of knowing each query's text.

## Production hardening

The reconciliation spec doesn't define an authentication mechanism, and real-world reconciliation
services (Wikidata's, GND's, etc.) are conventionally public — so this profile ships with no
request-rate limit and no auth requirement by default, matching that convention. Three things are
worth knowing if you're deploying this beyond local testing:

### Request-size caps

`reconcile-config.xql` declares four limits, all overridable like any other config value:

- `$reconc-config:MAX_BATCH_SIZE` (default 500) — the max number of queries in one `POST
  /api/reconcile` batch (both spec shapes: the 1.0-draft `queries` array and the 0.2 id-keyed
  object).
- `$reconc-config:MAX_EXTEND_IDS` / `$reconc-config:MAX_EXTEND_PROPERTIES` (default 500 / 100) — the
  max number of entity ids / properties in one `POST /api/reconcile/extend` request.
- `$reconc-config:MAX_LIMIT` (default 1000) — the max `"limit"` a single query or `/suggest/*` call
  can request.

The first three are **hard limits**: exceeding one gets the whole request rejected with HTTP 400,
never silently truncated. This is deliberate — reconciliation batch responses are strictly
*positional* (`results[i]` must correspond to `queries[i]`; `/extend`'s rows must cover every
requested id/property), so silently dropping entries would silently corrupt that correspondence for
the caller, which is worse than an explicit, actionable error. `MAX_LIMIT` instead **clamps**
silently: asking for "too many" results isn't actually invalid, just excessive, so the more
client-friendly behavior is to cap it and still answer, not reject the request.

### Rate limiting

Not implemented in-app, and deliberately so: eXist has no low-overhead, safe primitive for
tracking request counts across concurrent requests without adding DB I/O to every single request —
which would itself become a self-inflicted slowdown under load. The conventional, better place for
this is a reverse proxy in front of the app. For nginx:

```nginx
limit_req_zone $binary_remote_addr zone=reconcile:10m rate=10r/s;

location /exist/apps/tp-reconc/api/reconcile {
    limit_req zone=reconcile burst=20 nodelay;
    proxy_pass http://localhost:8080;
}
```

Adjust the zone/rate/burst to your expected traffic; a Traefik `RateLimit` middleware achieves the
same thing if that's your proxy of choice.

### Restricting access (optional)

`reconcile-api.tpl.json` already declares `basicAuth`/`cookieAuth` `securitySchemes` and a top-level
`"security"` requirement referencing them (this only makes roaster's `auth:standard-authorization`
middleware — already wired into every generated app's `modules/lib/api.xql` via `roaster:route/2` —
*attempt* to resolve a logged-in user per request; see `tei-publisher-roaster/content/auth.xql`). By
itself this does **not** restrict anything: a route is only actually gated once it also carries an
`"x-constraints"` object, checked by `auth:is-authorized-user`/`auth:is-public-route`. To make one
operation (or all of them) login-only, add `"x-constraints"` to the relevant operation object(s) in
`reconcile-api.tpl.json`, e.g.:

```json
"post": {
    "operationId": "reconc:reconcile",
    "x-constraints": { "groups": ["reconcile-users"] },
    ...
}
```

(`"user": ["alice", "bob"]` restricts to specific named accounts instead of/alongside a group.)
Regenerate the app; unauthenticated or non-matching requests then get HTTP 401. Do this per
operation you actually want private — leave the rest alone to keep them public, which is the right
default for a spec-conformant, OpenRefine-compatible service.

## Example: adding a fifth type

```xquery
"term": map {
    "name": "Keyword",
    "entities": function() as element()* {
        collection($config:register-root)/id($config:register-map?term?id)//tei:item[@xml:id]
    },
    "label": ".",
    "properties": map {}
}
```

(No `"view"` — falls back to the default ODD-based preview. No `"preview-mode"` — defaults to
`"register-overview"`. Property-free — still perfectly valid for reconciliation queries.)

## Testing

- `test/cypress/e2e/api/reconcile.cy.js` — the project's main integration suite (schema-validated
  against both spec versions), exercises the shipped defaults end-to-end over HTTP.
- `test/xqsuite/reconcile-config.xqm` — layer-1 unit tests, decoupled from HTTP: check the shipped
  defaults resolve against real register data, and separately prove the *mechanism* a custom config
  relies on (XPath-string extraction via `util:eval`, a swapped scoring function,
  `reconc-config:profile-installed` against both a real-and-present and a made-up-and-absent
  profile name, the fuzzy scoring tier on both a whole-word and a one-word-of-many typo, the
  `"labels"` extractor covering more than just the primary `"label"`, `reconc-config:gnd-uri-from-id`,
  and the new external-identifier properties resolving against real data) works, using stand-ins
  deliberately different from the shipped defaults where relevant.
- The Cypress suite also covers a misspelled single-token query still finding its match with a
  nonzero score, a batched query returning identical candidates to the same query sent alone (the
  batch-pool refactor doesn't change results), and the new `gnd`/`geonames`/`wikidata`/`occupation`
  extend properties resolving against real entities — including the `"gnd"` property defined on both
  `"person"` and `"work"` resolving against whichever type the requested entity actually is.
- `test/xqsuite/reconcile-conditions.xqm` — layer-1 unit tests for
  `reconc-cond:normalize-1.0`/`normalize-0.2`/`evaluate`/`matches-value`, modeled directly on the
  real spec fixtures published at https://github.com/reconciliation-api/specs
  (`examples/reconciliation-query-batch/valid/`, both spec versions).
  The Cypress suite covers the end-to-end HTTP behavior against this profile's own real demo data: a
  required property condition excluding a same-named non-match, the same condition matching and
  boosting instead, a direct `matchType: "id"` lookup, a property-only query with no name condition
  at all finding an entity purely by its `gnd` property (mirroring the spec's own "no query string"
  example), and the same behavior via 0.2's flatter `"properties"` array.
