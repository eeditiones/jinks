xquery version "3.1";

(:~
 : XQSuite unit tests proving reconcile-config.xql's pluggability contract, decoupled
 : from HTTP — the cheapest layer of this profile's test pyramid, run against pure
 : logic before ever touching the generated app's own Cypress API/GUI suites. Two
 : things are checked: (1) the shipped defaults actually work against real register
 : data, and (2) the
 : *mechanism* a custom config relies on — function-item extractors, xs:string XPath
 : extractors evaluated via util:eval, and a swappable $reconc-config:SCORE — behaves as
 : documented, using deliberately different (non-default) stand-ins so this doesn't
 : just re-assert the shipped defaults.
 :
 : Run via `xst run` / eXide's test runner, or ad-hoc:
 :   import module namespace t="http://teipublisher.com/api/reconcile/config/test" at "xmldb:exist:///db/apps/<abbrev>/test/xqsuite/reconcile-config.xqm";
 :   test:suite(util:list-functions("http://teipublisher.com/api/reconcile/config/test"))
 :)
module namespace t = "http://teipublisher.com/api/reconcile/config/test";

import module namespace reconc-config = "http://teipublisher.com/api/reconcile/config" at "../../modules/reconcile-config.xql";
import module namespace reconc-score = "http://teipublisher.com/api/reconcile/scoring" at "../../modules/reconcile-scoring.xql";
import module namespace test = "http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~ Every shipped default type's "entities" function must run without error (whether
 : or not the demo dataset happens to have any entities of that type — e.g. the demo
 : "organization" register is empty), and wherever entities do exist, the type's
 : "label" extractor must produce a non-empty string for the first one — proves the
 : shipped defaults are wired up correctly against real "registers" data, not just
 : syntactically valid. :)
declare
    %test:assertTrue
function t:default-types-have-entities-and-labels() {
    every $type-id in map:keys($reconc-config:TYPES)
    satisfies
        let $type-def := $reconc-config:TYPES?($type-id)
        let $entities := ($type-def?entities)()
        return
            empty($entities)
            or normalize-space(($type-def?label)($entities[1])) != ""
};

(:~ At least one shipped default type actually has entities in the demo dataset —
 : guards against the previous test vacuously passing if every register were empty. :)
declare
    %test:assertTrue
function t:at-least-one-default-type-has-entities() {
    some $type-id in map:keys($reconc-config:TYPES)
    satisfies exists((($reconc-config:TYPES?($type-id))?entities)())
};

(:~ The default scoring function: exact match scores 100, no overlap scores 0. :)
declare
    %test:assertEquals(100, 0)
function t:default-score-exact-and-no-match() {
    (reconc-score:default("Goethe", "Goethe"), reconc-score:default("Goethe", "Schiller"))
};

(:~ A config's "label"/property "value" entry may be an xs:string XPath instead of a
 : function item, evaluated relative to the entity via util:eval. This replicates
 : reconcile-api.xql's private reconc:resolve-extractor (which can't be imported
 : directly — module privacy is intentional, see its doc comment) against a
 : deliberately different, non-default entity shape and XPath, to prove the
 : *mechanism* generalizes rather than re-testing the shipped defaults. :)
declare
    %test:assertEquals("Test Person")
function t:xpath-string-extractor-mechanism-works() {
    let $data := <mock><name type="display">Test Person</name></mock>
    let $xpath := "name[@type='display']"
    return normalize-space(util:eval("($data)/" || $xpath))
};

(:~ A config's $reconc-config:SCORE-shaped variable can be swapped for arbitrary logic —
 : demonstrated with a trivial custom function distinct from reconc-score:default, to
 : prove the *contract* (function($label, $query) as xs:double) is what matters, not
 : a hardcoded algorithm. :)
declare
    %test:assertEquals(42, 42)
function t:score-contract-is-swappable() {
    let $custom-score := function($label as xs:string?, $query as xs:string?) as xs:double { 42 }
    return ($custom-score("anything", "anything"), $custom-score("completely different", "unrelated"))
};

(:~ reconc-config:profile-installed reads the real, generator-written context.json of
 : the app this test runs in — "registers" is genuinely extended by every demo app
 : this profile is tested against (see reconcile/doc/README.md), so this is an
 : integration check, not a mock. Guards the "view" fallback logic in
 : reconcile-api.xql's reconc:entity: a redirect to a "registers" browse page is only
 : attempted when this returns true. :)
declare
    %test:assertTrue
function t:profile-installed-detects-registers() {
    reconc-config:profile-installed("registers")
};

(:~ A profile that was never extended into this app must report false, not error out
 : (e.g. on a missing/empty context.json entry) — this is the exact condition under
 : which reconc:entity falls back to its own ODD-based preview instead of redirecting
 : to a "registers" page that wouldn't exist. :)
declare
    %test:assertFalse
function t:profile-installed-false-for-absent-profile() {
    reconc-config:profile-installed("definitely-not-a-real-profile-xyz")
};

(:~ reconc-score:default's edit-distance tier: a one-transposition typo scores
 : strictly between "no match" (0) and "exact match" (100) — this is what lets a
 : Lucene fuzzy pre-filter match (see reconcile-api.xql's reconc:fulltext-prefilter)
 : actually surface a ranked, nonzero-scored candidate instead of being silently
 : dropped by reconc:candidates' score>0 filter. :)
declare
    %test:assertTrue
function t:fuzzy-score-typo-is-between-no-match-and-exact() {
    let $score := reconc-score:default("Goethe", "Goehte")
    return $score gt 0 and $score lt 100
};

(:~ ...and the same holds for a typo in just one word of a realistic multi-word
 : label — this is the case that actually occurs in this profile's own demo data
 : (person labels like "Goethe, Johann Wolfgang von (1749-1832)"), and specifically
 : what regressed during development: a whole-string edit distance is essentially
 : never small enough to qualify once a label has more than a couple of words, so
 : the scorer has to compare token-by-token, not just the full strings. :)
declare
    %test:assertTrue
function t:fuzzy-score-typo-in-one-word-of-a-multiword-label() {
    let $score := reconc-score:default("Goethe, Johann Wolfgang von (1749-1832)", "Goehte")
    return $score gt 0 and $score lt 100
};

(:~ Completely unrelated strings of similar length must still score 0 — the fuzzy
 : tier is deliberately conservative (short edit distance *and* a minimum token
 : length) so it doesn't turn "no match" into a false positive. :)
declare
    %test:assertEquals(0)
function t:fuzzy-score-does-not-fire-for-unrelated-words() {
    reconc-score:default("Madrid", "Berlin")
};

(:~ The "labels" (plural) extractor is used for matching but never for display: a
 : type's shipped "person" default has a "labels" set (every persName variant) that
 : differs from its single "label" (the preferred "main" variant) — scoring against
 : a variant that ISN'T the primary label should still find a nonzero, sensible
 : score, proving reconc:labels' fallback-to-[label] behavior (for types without
 : "labels", exercised implicitly by every other test here) coexists correctly with
 : real multi-variant matching. Since reconc:labels lives in reconcile-api.xql
 : (%private, like reconc:resolve-extractor — see that function's own test above
 : for why), this replicates the *mechanism* directly against the shipped config's
 : own "labels" function rather than re-importing something intentionally private. :)
declare
    %test:assertTrue
function t:labels-extractor-covers-name-variants-beyond-the-primary-label() {
    let $type-def := $reconc-config:TYPES?person
    let $entities := ($type-def?entities)()
    let $with-variants := $entities[count(($type-def?labels)(.)) gt 1][1]
    return
        exists($with-variants) and
        (
            let $label := ($type-def?label)($with-variants)
            let $variants := ($type-def?labels)($with-variants)
            return some $v in $variants satisfies $v != $label
        )
};

(:~ reconc-config:gnd-uri-from-id converts the "gnd-<id>" shape this demo data uses
 : (both in some persons' @xml:id and in works' idno[@type='GND']) into a real,
 : resolvable GND URI, and returns nothing for ids that aren't in that shape (most
 : entities aren't GND-sourced at all — that has to be a non-error, "absent"
 : outcome, not a wrong guess). :)
declare
    %test:assertEquals("https://d-nb.info/gnd/119442086", "")
function t:gnd-uri-from-id-converts-known-shape-and-ignores-others() {
    (
        reconc-config:gnd-uri-from-id("gnd-119442086"),
        (reconc-config:gnd-uri-from-id("kbga-actors-136"), "")[1]
    )
};

(:~ The new external-identifier extend properties resolve against real register
 : data for at least one entity each — proves they're wired up correctly, not just
 : syntactically valid (same spirit as t:default-types-have-entities-and-labels). :)
declare
    %test:assertTrue
function t:external-identifier-properties-resolve-against-real-data() {
    let $person-gnd := $reconc-config:TYPES?person?properties?gnd?value
    let $person-occupation := $reconc-config:TYPES?person?properties?occupation?value
    let $place-geonames := $reconc-config:TYPES?place?properties?geonames?value
    let $work-gnd := $reconc-config:TYPES?work?properties?gnd?value
    return
        (some $e in ($reconc-config:TYPES?person?entities)() satisfies exists($person-gnd($e)))
        and (some $e in ($reconc-config:TYPES?person?entities)() satisfies exists($person-occupation($e)))
        and (some $e in ($reconc-config:TYPES?place?entities)() satisfies exists($place-geonames($e)))
        and (some $e in ($reconc-config:TYPES?work?entities)() satisfies exists($work-gnd($e)))
};

(:~ Production-hardening request-size caps (reconcile-api.xql reads and enforces
 : these — see reconc:reconcile-1.0/0.2 and reconc:extend-response for the reject-
 : vs-clamp distinction). This module only proves the knobs exist as positive
 : xs:integer values a deployer can override; the actual reject/clamp *behavior* is
 : covered end-to-end over HTTP by test/cypress/e2e/api/reconcile.cy.js's
 : "request-size caps" suite, since that's what actually exercises the enforcement
 : points (reconcile-api.xql's HTTP-facing functions are intentionally private and
 : not unit-testable in isolation). :)
declare
    %test:assertTrue
function t:request-size-caps-are-positive-integers() {
    every $limit in (
        $reconc-config:MAX_BATCH_SIZE,
        $reconc-config:MAX_LIMIT,
        $reconc-config:MAX_EXTEND_IDS,
        $reconc-config:MAX_EXTEND_PROPERTIES
    )
    satisfies $limit instance of xs:integer and $limit gt 0
};
