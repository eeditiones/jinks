xquery version "3.1";

(:~
 : Lucene fuzzy-query helper shared between reconcile-config.xql (whose
 : "fulltext-search" closures build the query string themselves, directly inside
 : their own path expression) and reconcile-api.xql (which only calls those
 : closures, never builds a query itself) — a small standalone module rather than
 : living in either, since api imports config and a helper needed by both would
 : otherwise force a circular import.
 :)
module namespace reconc-fulltext = "http://teipublisher.com/api/reconcile/fulltext";

(:~ Escapes Lucene QueryParser special characters in a raw query token so it can't
 : break out of the field:(...) query string reconc-fulltext:fuzzy-query builds. This
 : is now mostly a defensive no-op for the tokens fuzzy-query actually passes it (see
 : below — tokenizing on non-word-character boundaries means a token can no longer
 : itself contain any of these characters), kept as a safety net rather than removed.
 : ("&amp;" here is XQuery's predefined entity reference for a literal "&" character —
 : valid inside any XQuery string literal per the language spec, not XML markup; do
 : not "simplify" this to a bare "&", which is a syntax error. :)
declare %private function reconc-fulltext:escape-token($token as xs:string) as xs:string {
    replace($token, '([+\-!(){}\[\]^"~*?:\\/&amp;])', '\\$1')
};

(:~ Builds a fuzzy Lucene query string for a full-text pre-filter: every
 : word-character-boundary token of $query — i.e. split the same way
 : reconc-score:tokenize-words already does for scoring, not merely on whitespace —
 : gets Lucene's classic QueryParser "~" fuzzy operator, scoped to $field — e.g. field
 : "name", query "Goehte" becomes "name:(goehte~)". Splitting on whitespace alone (the
 : original behaviour) let a token retain internal punctuation, e.g. a person label's
 : trailing "(1846-1922)" life-date range stayed one token "\(1846\-1922\)" after
 : escaping — but Lucene's own field analyzer still tokenizes that PARSED term's text
 : into "1846"/"1922" during query execution, and a fuzzy ("~") operator cannot apply
 : to what the analyzer splits into more than one term, so the whole query failed with
 : "Analyzer created multiple terms for ...", a real, reproducible 500 for any person
 : whose full display name includes a life-date range (confirmed live against a name
 : containing "(1846-1922)"). Tokenizing on non-word-character boundaries up front
 : avoids ever constructing an unparseable fuzzy term in the first place, and is also
 : the more correct behavior: "1846" and "1922" now become independent fuzzy terms,
 : instead of an intended-but-previously-unreachable single "1846-1922" match unit.
 : Meant to be embedded directly inside an ft:query() predicate that is itself part of
 : the same path expression doing the collection lookup (e.g. "collection(...)//tei:person
 : [ft:query(., reconc-fulltext:fuzzy-query(...))]") — critically *not* applied
 : afterwards as a filter on an already-materialized node sequence, which prevents
 : eXist from using the Lucene index at all (~300x slower in testing against this
 : project's demo data: 3ms vs. 955ms for the same 33-entity collection). Matches
 : found this way still get their final 0-100 score from $reconc-config:SCORE
 : afterwards — Lucene is only used to shortlist candidates cheaply, not to rank them. :)
declare function reconc-fulltext:fuzzy-query($field as xs:string, $query as xs:string) as xs:string {
    let $tokens := tokenize($query, "[^\p{L}\p{N}]+")[. != ""]
    return
        $field || ":(" || string-join(for $t in $tokens return reconc-fulltext:escape-token($t) || "~", " ") || ")"
};
