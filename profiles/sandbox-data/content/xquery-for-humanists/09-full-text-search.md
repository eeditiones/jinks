# XQuery Full Text Search

XQuery Full Text extends the language with the `contains text` expression for sophisticated text searching — including phrase matching, proximity, scoring, stemming, wildcards, and stop words.

## Basic String Searching

Before diving into full text, recall XPath's string functions:

```xquery
let $text := "Among other public buildings in a certain town,
    which for many reasons it will be prudent to refrain from
    mentioning, and to which I will assign no fictitious name,
    there is one anciently common to most towns, great or small:
    to wit, a workhouse"
return (
    fn:contains($text, "workhouse"),
    fn:starts-with($text, "Among"),
    fn:matches($text, "public")
)
```

These work for simple cases but can't handle word boundaries, scoring, or linguistic features.

## The contains text Expression

`contains text` provides full-text search capabilities:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $poem := <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
        <fileDesc>
            <titleStmt>
                <title>The Best Thing in the World</title>
                <author>Elizabeth Barrett Browning</author>
            </titleStmt>
            <publicationStmt><p>The Poetical Works, Vol. IV</p></publicationStmt>
            <sourceDesc><p>Project Gutenberg</p></sourceDesc>
        </fileDesc>
    </teiHeader>
    <text>
        <body>
            <l>What's the best thing in the world?</l>
            <l>June-rose, by May-dew impearled;</l>
            <l>Sweet south-wind, that means no rain;</l>
            <l>Truth, not cruel to a friend;</l>
            <l>Pleasure, not in haste to end;</l>
            <l>Beauty, not self-decked and curled</l>
            <l>Till its pride is over-plain;</l>
            <l>Light, that never makes you wink;</l>
            <l>Memory, that gives no pain;</l>
            <l>Love, when, so, you're loved again.</l>
            <l>What's the best thing in the world?</l>
            <l>—Something out of it, I think.</l>
        </body>
    </text>
</TEI>;

$poem/tei:text/tei:body/tei:l[. contains text "Memory"]
```

Unlike `fn:contains()`, `contains text` is word-aware and case-insensitive by default.

## Quantifiers

Control how multiple search terms are matched:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $poem := <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text xmlns="http://www.tei-c.org/ns/1.0"><body>
        <l>What's the best thing in the world?</l>
        <l>June-rose, by May-dew impearled;</l>
        <l>Sweet south-wind, that means no rain;</l>
        <l>Truth, not cruel to a friend;</l>
        <l>Pleasure, not in haste to end;</l>
        <l>Beauty, not self-decked and curled</l>
        <l>Till its pride is over-plain;</l>
        <l>Light, that never makes you wink;</l>
        <l>Memory, that gives no pain;</l>
        <l>Love, when, so, you're loved again.</l>
        <l>What's the best thing in the world?</l>
        <l>—Something out of it, I think.</l>
    </body></text>
</TEI>;

let $lines := $poem/tei:text/tei:body/tei:l
return (
    (: any — match if any term is found :)
    $lines[. contains text {"happiness", "joy", "pleasure"} any],

    (: phrase — terms must appear as an ordered phrase :)
    $lines[. contains text {"makes", "you", "wink"} phrase],

    (: any word — match any word from a phrase string :)
    $lines[. contains text {"makes you sneeze"} any word]
)
```

## Occurrence Counts

Require a term to appear a specific number of times:

```xquery
let $text :=
    "She sells sea-shells on the sea-shore.
    The shells she sells are sea-shells, I'm sure.
    For if she sells sea-shells on the sea-shore
    Then I'm sure she sells sea-shore shells."
return (
    $text contains text "shells" occurs at least 2 times,
    $text contains text "shells" occurs exactly 2 times,
    $text contains text "shells" occurs from 2 to 6 times
)
```

## Boolean Operators

Combine search terms with `ftand`, `ftor`, and `ftnot`:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $poem := <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text xmlns="http://www.tei-c.org/ns/1.0"><body>
        <l>What's the best thing in the world?</l>
        <l>Truth, not cruel to a friend;</l>
        <l>Pleasure, not in haste to end;</l>
        <l>Light, that never makes you wink;</l>
        <l>Memory, that gives no pain;</l>
        <l>Love, when, so, you're loved again.</l>
        <l>What's the best thing in the world?</l>
        <l>—Something out of it, I think.</l>
    </body></text>
</TEI>;

let $lines := $poem/tei:text/tei:body/tei:l
return (
    (: OR — either term :)
    $lines[. contains text ("memory" ftor "love")],

    (: AND — both terms :)
    $lines[. contains text ("truth" ftand "cruel")],

    (: NOT — exclude a term :)
    $lines[. contains text (ftnot "world" ftand "in")]
)
```

## Positional Filters

Constrain where matches occur:

```xquery
let $text := "Among other public buildings in a certain town"
return (
    $text contains text "among" at start,
    $text contains text "town" at end,
    "This is a complete sentence."
        contains text "this is a complete sentence" entire content
)
```

## Proximity

Find terms that appear near each other:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $poem := <TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text xmlns="http://www.tei-c.org/ns/1.0"><body>
        <l>Light, that never makes you wink;</l>
        <l>Memory, that gives no pain;</l>
    </body></text>
</TEI>;

(
    (: distance — maximum gap between terms :)
    $poem contains text ("light" ftand "wink") distance at most 6 words,

    (: window — all terms must appear within N words :)
    $poem contains text ("light" ftand "wink") window 6 words
)
```

## Scoring and Weighting

Full-text matches produce relevance scores. Use `weight` to boost matches in specific fields:

```xquery
let $documents :=
    <documents>
        <document>
            <title>The Secretary of State to the Consul at Taipei</title>
            <body>Dept notes ur statement "question being asked locally".</body>
        </document>
        <document>
            <title>The Ambassador in China to the Secretary of State</title>
            <body>Col. Dau returned from Taipei Mar. 11 and his view
                situation telegraphed War Department.</body>
        </document>
    </documents>
let $query-term := "Taipei"
for $document score $score in $documents/document
    [
        title contains text ({$query-term} weight {10})
        or
        body contains text ({$query-term})
    ]
order by $score descending
return
    <hit score="{fn:format-number($score, '0.00')}">{$document/title}</hit>
```

Title matches are weighted 10x higher than body matches.

## Match Options

Fine-tune matching behavior:

```xquery
(
    (: Case sensitivity :)
    "Have you read The Crimson Petal and the White?"
        contains text "crimson petal" using case sensitive,

    (: Diacritics :)
    "Félix Guattari was a co-author of Anti-Oedipus"
        contains text "Felix" using diacritics sensitive,

    (: Wildcards — . matches single character :)
    "Shall we analyse this text?"
        contains text "analy.e" using wildcards,

    (: Stemming — matches word forms :)
    "I saw him swimming in the pool."
        contains text "swim" using stemming,

    (: Stop words — ignore common words :)
    "The Heir of Redclyffe"
        contains text "An Heir of Redclyffe"
        using stop words ("a", "an", "the", "of", "to"),

    (: Combine options :)
    "We are Princetonians"
        contains text "Princetonian"
        using stemming using case sensitive
)
```
