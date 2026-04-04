# Sequences and Functions

XQuery provides powerful tools for working with ordered sequences and for defining reusable functions.

## Sequence Operations

Sequences are the fundamental data structure in XQuery. You can access items by position, extract subsequences, and find items:

```xquery
let $cities := ("New York", "Paris", "Tokyo", "Buenos Aires")
return (
    fn:head($cities),
    fn:tail($cities),
    $cities[3],
    $cities[position() = (1, 3)],
    fn:index-of($cities, "Tokyo"),
    fn:subsequence($cities, 2, 2)
)
```

`fn:head()` returns the first item, `fn:tail()` returns everything except the first. `fn:subsequence($seq, $start, $length)` extracts a slice.

## String Functions

XQuery includes many useful string functions:

```xquery
(
    fn:substring("I love XQuery", 8),
    fn:substring("I love XQuery", 3, 4),
    fn:concat("Nashville", ", ", "TN"),
    fn:string-join(("red", "white", "blue"), " "),
    fn:string-join(("red", "white", "blue"))
)
```

`fn:string-join()` without a separator concatenates with no delimiter — useful for joining character sequences.

## Declaring Functions

Use `declare function` to define reusable functions. Type annotations on parameters catch errors early:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:make-tei-title(
    $title as xs:string,
    $subtitle as xs:string?
) as element(tei:title) {
    <title type="full" xmlns="http://www.tei-c.org/ns/1.0">
        <title type="main">{$title}</title>
        <title type="sub">{$subtitle}</title>
    </title>
};

local:make-tei-title("Citizens at Last", "The Woman Suffrage Movement in Texas")
```

The `?` after `xs:string` means the parameter is optional — it accepts an empty sequence.

## What Happens Without Types

Without type annotations, functions accept any input — which can lead to surprising results:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:make-tei-title($title, $subtitle) {
    <title type="full" xmlns="http://www.tei-c.org/ns/1.0">
        <title type="main">{$title}</title>
        <title type="sub">{$subtitle}</title>
    </title>
};

(: This works but produces unexpected output —
   an element and a two-item sequence instead of two strings :)
local:make-tei-title(
    <title>Citizens at Last</title>,
    ("The Woman Suffrage Movement in Texas", "and Tennessee")
)
```

## Anonymous Functions

Functions can be assigned to variables and passed as arguments:

```xquery
let $title := "Citizens at Last"
let $subtitle := "The Woman Suffrage Movement in Texas"
let $join-titles :=
    function($title as xs:string, $subtitle as xs:string) as xs:string {
        fn:concat($title, ": ", $subtitle)
    }
return
    $join-titles($title, $subtitle)
```

## Constructing XML

XQuery can construct XML directly. Curly braces `{}` mark enclosed expressions that get evaluated:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

<placeName xmlns="http://www.tei-c.org/ns/1.0">
    {fn:concat("Nashville", ", ", "TN")}
</placeName>
```

Without the curly braces, the `fn:concat(...)` call would appear as literal text in the output rather than being evaluated.

## Embedded Expressions

You can embed any XQuery expression inside XML constructors:

```xquery
<p>Wicentowski is {fn:string-length("Wicentowski")}
    letters long in the Roman alphabet, but only
    {fn:string-length("ウィセントースキ")}
    in Japanese kana.</p>
```
