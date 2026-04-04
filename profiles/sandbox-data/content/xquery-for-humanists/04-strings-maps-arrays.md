# Strings, Maps, and Arrays

XQuery 3.1 introduced maps and arrays alongside the familiar sequences and strings, giving you flexible data structures for both XML and non-XML data.

## String Concatenation

The `||` operator is a concise alternative to `fn:concat()`:

```xquery
let $book-count := 100
return
    "You have " || $book-count || " books in the database."
```

For joining a *sequence* of strings, use `fn:string-join()`:

```xquery
let $colors := ("red", "white", "blue")
return
    fn:string-join($colors, " ")
```

## String Constructors

String constructors (template literals) let you build multi-line strings with embedded expressions using `` `{ }` ``:

```xquery
let $name := "XQuery Working Group"
return
``[
@prefix foaf: <http://xmlns.com/foaf/0.1/> .

_:xqywg a foaf:Group;
  foaf:name "`{$name}`" .
]``
```

This is especially useful for generating output in non-XML formats like RDF/Turtle, CSV, or plain text.

## Sequences vs. Empty Sequences

Sequences flatten automatically — nested sequences become one flat sequence:

```xquery
(("China", "Russia", "Japan"), ("Mexico", "Canada", "United States"))
```

This produces a single sequence of 6 items, not a nested structure.

Empty sequences `()` disappear when included in a sequence:

```xquery
(
    ((), "China", "Russia", (), "Turkey"),
    ("", "China", "Russia", "", "Turkey")
)
```

The first produces 3 items (empty sequences vanish). The second produces 5 items (empty strings are real values).

## Maps

Maps are key-value data structures. Create them with `map {}` and access values with `?` or function-call syntax:

```xquery
let $article :=
    map {
        "title": "On Teaching XQuery to Digital Humanists",
        "author": "https://orcid.org/0000-0003-0328-0792",
        "identifier": "10.4242/BalisageVol13.Anderson01"
    }
return (
    $article?title,
    $article("identifier")
)
```

## Nested Maps

Maps can contain other maps. Chain the `?` operator to navigate nested structures:

```xquery
let $article :=
    map {
        "titles": map {
            "english": "On Teaching XQuery to Digital Humanists",
            "chinese": "如何給數位人文研究者教 XQuery"
        }
    }
return (
    $article?titles?chinese,
    map:find($article, "chinese")
)
```

`map:find()` searches recursively through all nested maps for the given key.

## The Wildcard Lookup

The `?*` operator retrieves all values from a map or array:

```xquery
let $countries :=
    map {
        "eastern-countries": ["China", "Russia", "Japan"],
        "western-countries": ["Mexico", "Canada", "United States"]
    }
return (
    $countries?*,       (: all values — both arrays :)
    $countries?*?1      (: first element of each array :)
)
```

## Arrays

Unlike sequences, arrays preserve nesting. Create them with `[]` or `array {}`:

```xquery
let $flat-sequence := (("China", "Russia"), ("Mexico", "Canada"))
let $nested-array := [["China", "Russia"], ["Mexico", "Canada"]]
return (
    count($flat-sequence),  (: 4 — sequences flatten :)
    array:size($nested-array),  (: 2 — arrays preserve structure :)
    $nested-array?1?2       (: "Russia" — chained lookup :)
)
```

## Array Operations

```xquery
let $eastern := ["China", "Russia", "Japan"]
let $western := ["Mexico", "Canada", "United States"]
return (
    array:append($eastern, "Indonesia"),
    array:join(($eastern, $western)),
    array:flatten([["a", ["b", "c"]], "d"])
)
```

`array:join()` concatenates arrays into one flat array. `array:flatten()` recursively unwraps nested arrays into a sequence.

## Combining Maps

Use `map:merge()` to combine multiple maps and `map:put()` to add or update entries:

```xquery
let $countries :=
    map {
        "eastern": ["China", "Russia", "Japan"],
        "western": ["Mexico", "Canada", "United States"]
    }
let $eastern := array:append($countries("eastern"), "Indonesia")
return
    map:put($countries, "eastern", $eastern)
```

Maps are immutable — `map:put()` returns a *new* map with the updated entry.

## Windowing

Window clauses partition sequences into overlapping or non-overlapping groups — useful for detecting patterns across consecutive items.

### Tumbling Windows

A tumbling window creates non-overlapping groups. Here we detect consecutive duplicate words:

```xquery
let $sentence := "This is a a test of of windowing"
let $words := fn:tokenize($sentence, " ")
for tumbling window $w in $words
    start $start-word at $pos
    next $next-word
    when $start-word eq $next-word
return
    <duplicate position="{$pos}">{$start-word}</duplicate>
```

### Sliding Windows

A sliding window creates overlapping groups. Here we generate trigrams (3-word n-grams):

```xquery
let $sentence := "I hope you have a nice day!"
let $tokens := fn:tokenize($sentence, " ")
let $ngram-length := 3

for sliding window $ngram in $tokens
    start at $starting-pos
        when true()
    only end at $ending-pos
        when $ending-pos - $starting-pos + 1 eq $ngram-length
return
    <ngram>{$ngram}</ngram>
```

The `only` keyword ensures incomplete windows at the end of the sequence are excluded.
