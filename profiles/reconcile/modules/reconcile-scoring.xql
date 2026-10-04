xquery version "3.1";

(:~
 : Default matching/ranking algorithms for the reconcile profile. Public and
 : composable on purpose: a customized reconcile-config.xql can point
 : $reconc-config:SCORE at reconc-score:default#2 directly, or wrap/combine it with
 : its own logic (e.g. "call the default, then boost exact-language matches").
 :)
module namespace reconc-score = "http://teipublisher.com/api/reconcile/scoring";

declare %private function reconc-score:normalize-text($s as xs:string?) as xs:string {
    lower-case(normalize-space($s))
};

(:~ Levenshtein (edit) distance between two strings — classic Wagner-Fischer DP, one
 : array per row (rows kept as a growing sequence rather than a rolling pair since
 : candidate labels are short; not worth the extra complexity of a 2-row version).
 : No built-in equivalent ships with eXist (checked: no util:/functx: edit-distance
 : function is resolvable in this environment) so this is hand-rolled. :)
declare %private function reconc-score:levenshtein($a as xs:string, $b as xs:string) as xs:integer {
    let $la := string-length($a)
    let $lb := string-length($b)
    return
        if ($la eq 0) then
            $lb
        else if ($lb eq 0) then
            $la
        else
            let $ca := string-to-codepoints($a)
            let $cb := string-to-codepoints($b)
            let $rows :=
                fold-left(1 to $la, (array { 0 to $lb }), function($rows as array(*)*, $i as xs:integer) as array(*)* {
                    let $prev := $rows[last()]
                    let $new-row :=
                        fold-left(1 to $lb, (array { $i }), function($row as array(*), $j as xs:integer) as array(*) {
                            let $cost := if ($ca[$i] eq $cb[$j]) then 0 else 1
                            let $del := $prev($j + 1) + 1
                            let $ins := $row(array:size($row)) + 1
                            let $sub := $prev($j) + $cost
                            return array:append($row, min(($del, $ins, $sub)))
                        })
                    return ($rows, $new-row)
                })
            return $rows[last()]($lb + 1)
};

(:~ 0-100 similarity from a precomputed edit distance, relative to the longer
 : string's length — 100 for identical strings (distance 0), decreasing linearly
 : with how much editing is needed. :)
declare %private function reconc-score:fuzzy-similarity($l as xs:string, $q as xs:string, $distance as xs:integer) as xs:double {
    let $max-len := max((string-length($l), string-length($q)))
    return
        if ($max-len eq 0) then
            0
        else
            100.0 * (1 - ($distance div $max-len))
};

(:~ Splits on any run of non-letter/non-digit characters (not just whitespace), so
 : punctuation attached to a word ("Goethe," / "(1749-1832)") doesn't become part
 : of the token and throw off exact- or fuzzy-token comparison. :)
declare %private function reconc-score:tokenize-words($s as xs:string) as xs:string* {
    tokenize($s, "[^\p{L}\p{N}]+")[. != ""]
};

(:~ How well a single query token matches a single label token: 1.0 for an exact
 : match, a fraction of 1.0 (from reconc-score:fuzzy-similarity) for a probable
 : typo (both tokens at least 4 characters, edit distance at most 2), otherwise 0.
 : Used per-token so a typo in just *one* word of a multi-word label/query (e.g.
 : query "Goehte" against a label token "goethe") still counts as a match — a
 : whole-string edit distance would rarely be small enough to qualify once names
 : have more than a couple of words. :)
declare %private function reconc-score:token-similarity($a as xs:string, $b as xs:string) as xs:double {
    if ($a eq $b) then
        xs:double(1)
    else if (string-length($a) lt 4 or string-length($b) lt 4) then
        xs:double(0)
    else
        let $distance := reconc-score:levenshtein($a, $b)
        return
            if ($distance le 2) then
                reconc-score:fuzzy-similarity($a, $b, $distance) div 100.0
            else
                xs:double(0)
};

(:~
 : Simple 0-100 similarity score between a candidate label and the query string:
 : 100 for an exact (case/whitespace-insensitive) match, a length-ratio score for
 : substring containment either way, otherwise a token-overlap ratio — where each
 : query word contributes up to 1.0 "shared" credit for an exact match in the
 : label, or a fraction of that (see reconc-score:token-similarity) for a likely
 : typo of one of the label's words. This is what gives a typo anywhere in a
 : multi-word query (e.g. "Wilhelm Goehte" against label "Goethe, Johann Wolfgang
 : von") a meaningful nonzero score, not just a whole-query/whole-label typo.
 :)
declare function reconc-score:default($label as xs:string?, $query as xs:string?) as xs:double {
    let $l := reconc-score:normalize-text($label)
    let $q := reconc-score:normalize-text($query)
    return
        if ($q eq "" or $l eq "") then
            0
        else if ($l eq $q) then
            100
        else if (contains($l, $q) or contains($q, $l)) then
            100.0 * (2 * min((string-length($l), string-length($q)))) div (string-length($l) + string-length($q))
        else
            let $l-tokens := reconc-score:tokenize-words($l)
            let $q-tokens := reconc-score:tokenize-words($q)
            let $credit :=
                sum(
                    for $qt in distinct-values($q-tokens)
                    return max((xs:double(0), for $lt in $l-tokens return reconc-score:token-similarity($qt, $lt)))
                )
            return
                if ($credit eq 0) then
                    0
                else
                    100.0 * (2 * $credit) div (count($l-tokens) + count($q-tokens))
};
