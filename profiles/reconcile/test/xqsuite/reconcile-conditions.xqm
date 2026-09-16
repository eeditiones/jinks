xquery version "3.1";

(:~
 : XQSuite unit tests for reconcile-conditions.xql — the wire-shape normalization and
 : property/id match-condition evaluation that lets reconc:candidates
 : (reconcile-api.xql) match on more than just a plain name query. The cheapest layer
 : of this profile's test pyramid, fully decoupled from HTTP; the end-to-end HTTP
 : behavior (required filtering, optional boosting, id lookups, property-only queries)
 : is covered by test/cypress/e2e/api/reconcile.cy.js instead, against this profile's
 : own real demo data.
 :
 : Query shapes below are deliberately modeled on the real fixtures published at
 : https://github.com/reconciliation-api/specs (examples/reconciliation-query-batch/
 : valid/, for both the 0.2 and 1.0-draft spec versions — checked directly, not from
 : memory) rather than invented ad hoc.
 :
 : Run via `xst run` / eXide's test runner, or ad-hoc:
 :   import module namespace t="http://teipublisher.com/api/reconcile/conditions/test" at "xmldb:exist:///db/apps/<abbrev>/test/xqsuite/reconcile-conditions.xqm";
 :   test:suite(util:list-functions("http://teipublisher.com/api/reconcile/conditions/test"))
 :)
module namespace t = "http://teipublisher.com/api/reconcile/conditions/test";

import module namespace reconc-cond = "http://teipublisher.com/api/reconcile/conditions" at "../../modules/reconcile-conditions.xql";
import module namespace test = "http://exist-db.org/xquery/xqsuite" at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

(:~ matches-value's default (no qualifier) rule: case-insensitive exact-or-substring —
 : the same "good enough" spirit 0.2 conditions always use, since 0.2 has no
 : matchQualifier concept at all. :)
declare
    %test:assertEquals(1, 1, 0)
function t:matches-value-default-is-case-insensitive-substring() {
    (
        xs:integer(reconc-cond:matches-value("Hello", "hello", ())),
        xs:integer(reconc-cond:matches-value("Johann Wolfgang Goethe", "Goethe", ())),
        xs:integer(reconc-cond:matches-value("Schiller", "Goethe", ()))
    )
};

declare
    %test:assertEquals(1, 0)
function t:matches-value-exact-match-is-case-sensitive-and-not-substring() {
    (
        xs:integer(reconc-cond:matches-value("Goethe", "Goethe", "ExactMatch")),
        xs:integer(reconc-cond:matches-value("goethe", "Goethe", "ExactMatch"))
    )
};

declare
    %test:assertEquals(1, 0)
function t:matches-value-wildcard-match-translates-star-to-any-run() {
    (
        xs:integer(reconc-cond:matches-value("Politiker", "Politik*", "WildcardMatch")),
        xs:integer(reconc-cond:matches-value("Lehrer", "Politik*", "WildcardMatch"))
    )
};

(:~ An entity-reference $wanted ({"id": ..., "name": ...} — per the spec's
 : property_value definition, "a property value which represents another entity")
 : compares on its "id", not its "name". :)
declare
    %test:assertTrue
function t:matches-value-entity-reference-wanted-compares-on-id() {
    reconc-cond:matches-value("Q681964", map { "id": "Q681964", "name": "Madrid" }, "ExactMatch")
};

(:~ Modeled directly on reconciliation-api/specs' 1.0-draft example-full.json: a name
 : condition plus two property conditions, one required with ExactMatch, one
 : optional with WildcardMatch. :)
declare
    %test:assertEquals("Christel Hanewinckel", 2, 0, 1, "WildcardMatch", "ExactMatch")
function t:normalize-1.0-extracts-name-and-property-conditions() {
    let $query := map {
        "type": "DifferentiatedPerson",
        "limit": 5,
        "conditions": [
            map { "matchType": "name", "propertyValue": "Christel Hanewinckel" },
            map { "matchType": "property", "propertyId": "professionOrOccupation", "propertyValue": "Politik*",
                  "required": false(), "matchQuantifier": "any", "matchQualifier": "WildcardMatch" },
            map { "matchType": "property", "propertyId": "affiliation", "propertyValue": "http://d-nb.info/gnd/2022139-3",
                  "required": true(), "matchQuantifier": "any", "matchQualifier": "ExactMatch" }
        ]
    }
    let $norm := reconc-cond:normalize-1.0($query)
    return (
        $norm?name,
        array:size($norm?properties),
        xs:integer($norm?properties?1?required),
        xs:integer($norm?properties?2?required),
        $norm?properties?1?qualifier,
        $norm?properties?2?qualifier
    )
};

(:~ Modeled directly on reconciliation-api/specs' no-query-string.json: a query with only a
 : property condition, no name condition at all — this is the exact shape that
 : returned zero candidates before this feature existed (reconc:query-text-from-conditions
 : found no "name" condition and nothing else was ever consulted). :)
declare
    %test:assertTrue
function t:normalize-1.0-handles-a-query-with-no-name-condition-at-all() {
    let $query := map { "conditions": [ map { "matchType": "property", "propertyId": "uid", "propertyValue": "27eb892afbb2" } ] }
    let $norm := reconc-cond:normalize-1.0($query)
    return empty($norm?name) and array:size($norm?properties) = 1
};

(:~ matchType="id" conditions populate "ids", not "properties" — this is the direct
 : entity-lookup path in reconc:candidates, bypassing name/property matching
 : entirely for candidate *generation* (though property conditions, if any, still
 : apply afterwards). :)
declare
    %test:assertEquals("entity-42")
function t:normalize-1.0-extracts-id-conditions() {
    reconc-cond:normalize-1.0(map { "conditions": [ map { "matchType": "id", "propertyValue": "entity-42" } ] })?ids
};

(:~ Modeled on reconciliation-api/specs' multi-values.json: propertyValue as an array (mixing
 : a plain string and an entity-reference object) normalizes to a plain sequence of
 : two values, not a single array-typed value. :)
declare
    %test:assertEquals(2)
function t:normalize-1.0-flattens-an-array-propertyValue() {
    let $query := map {
        "conditions": [
            map { "matchType": "name", "propertyValue": "Christel Hanewinckel" },
            map { "matchType": "property", "propertyId": "professionOrOccupation",
                  "propertyValue": [ "Politik*", map { "id": "wissenschaftler", "name": "Wissenschaftler(in)" } ] }
        ]
    }
    return count(reconc-cond:normalize-1.0($query)?properties?1?values)
};

(:~ 0.2's flatter {query, properties:[{pid,v}]} shape — no required/quantifier/qualifier
 : concept, so every property condition normalizes to optional + default matching. :)
declare
    %test:assertEquals("Christel Hanewinckel", 1, 0)
function t:normalize-0.2-extracts-query-and-properties() {
    let $query := map { "query": "Christel Hanewinckel", "properties": [ map { "pid": "professionOrOccupation", "v": "Politik*" } ] }
    let $norm := reconc-cond:normalize-0.2($query)
    return ($norm?name, array:size($norm?properties), xs:integer($norm?properties?1?required))
};

(:~ evaluate()'s quantifier semantics ("any"/"all"/"none") against a multi-valued
 : extracted property and a multi-valued wanted list. :)
declare
    %test:assertEquals(1, 0, 1)
function t:evaluate-quantifier-any-all-none() {
    let $extractor := function($e as element()) as xs:string* { $e/occupation/string() }
    let $entity := <person><occupation>Politiker</occupation><occupation>Lehrer</occupation></person>
    return (
        xs:integer(reconc-cond:evaluate($extractor, $entity, map { "id": "occupation", "values": ("Politiker", "Arzt"), "required": false(), "quantifier": "any", "qualifier": "ExactMatch" })?matched),
        xs:integer(reconc-cond:evaluate($extractor, $entity, map { "id": "occupation", "values": ("Politiker", "Arzt"), "required": false(), "quantifier": "all", "qualifier": "ExactMatch" })?matched),
        xs:integer(reconc-cond:evaluate($extractor, $entity, map { "id": "occupation", "values": ("Arzt", "Bischof"), "required": false(), "quantifier": "none", "qualifier": "ExactMatch" })?matched)
    )
};

(:~ A missing extractor (the type doesn't define this property at all) never
 : matches, rather than erroring — the exact condition under which reconc:candidates
 : must exclude every candidate for a *required* condition on an undefined property,
 : and simply not boost for an optional one. :)
declare
    %test:assertFalse
function t:evaluate-with-no-extractor-never-matches() {
    reconc-cond:evaluate((), <person/>, map { "id": "nonexistent", "values": ("anything"), "required": false(), "quantifier": "any", "qualifier": () })?matched
};

(:~ Same invariant, but for quantifier "none" specifically — a real, previously-shipped bug:
 : "not(some $m in (false()) satisfies $m)" is true(), so a missing extractor used to make a
 : "none" condition match every candidate instead of none. :)
declare
    %test:assertFalse
function t:evaluate-with-no-extractor-never-matches-for-none-quantifier() {
    reconc-cond:evaluate((), <person/>, map { "id": "nonexistent", "values": ("anything"), "required": false(), "quantifier": "none", "qualifier": () })?matched
};
