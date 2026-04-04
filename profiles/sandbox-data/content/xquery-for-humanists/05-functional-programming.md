# Thinking Functionally

XQuery encourages a functional programming style: immutable variables, function composition, and recursion instead of mutable state and loops.

## Variable Rebinding

XQuery variables are immutable — you can't change a value once bound. But you can *rebind* a variable name in a new `let` clause, which creates a new binding that shadows the old one:

```xquery
let $name := "Franklin D. Roosevelt"
let $url := fn:lower-case($name)
let $url := fn:replace($url, "\W+", "-")
return
    $url
```

Each `let` creates a new scope — the old `$url` still exists, it's just no longer visible.

## The Arrow Operator

The arrow operator `=>` pipes a value into a function as its first argument, creating a readable left-to-right pipeline:

```xquery
let $name := "Franklin D. Roosevelt"
let $url := fn:lower-case($name) => fn:replace("\W+", "-")
return
    $url
```

This is equivalent to `fn:replace(fn:lower-case($name), "\W+", "-")` but reads more naturally.

## The Simple Map Operator

The `!` operator applies an expression to each item in a sequence:

```xquery
("PLEASE", "DO", "NOT", "SHOUT") ! fn:lower-case(.)
```

It's more concise than `for $x in ... return ...` when you just need to transform each item.

## fold-left

`fn:fold-left()` reduces a sequence to a single value by applying a function that accumulates results:

```xquery
let $phrase := "When in the Course of human events,
    it becomes necessary for one people to dissolve the
    political bands which have connected them with another"
let $words := fn:tokenize($phrase, "\s+") ! fn:replace(., "\W", "")
let $add-length :=
    function($total as xs:integer, $word as xs:string) as xs:integer {
        fn:string-length($word) + $total
    }
return
    fn:fold-left($words, 0, $add-length) div fn:count($words)
```

This computes the average word length by folding a length-accumulating function over each word.

## Recursion

Recursive functions call themselves, making them ideal for processing tree-structured data:

```xquery
declare function local:is-palindrome($phrase as xs:string?) as xs:boolean {
    let $codepoints := fn:string-to-codepoints($phrase)
    let $first := $codepoints[1]
    let $last := $codepoints[last()]
    return
        if (fn:empty($first)) then
            true()
        else if ($first ne $last) then
            false()
        else
            let $middle := $codepoints[position() = 2 to last() - 1]
            return
                local:is-palindrome(fn:codepoints-to-string($middle))
};

(
    local:is-palindrome("racecar"),
    local:is-palindrome("hello")
)
```

## Typeswitch Transformations

`typeswitch` dispatches on the type of a node, making it ideal for recursive XML-to-HTML transformations:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $doc := <div xmlns="http://www.tei-c.org/ns/1.0">
    <p>Lincoln is dead! The body of the victim of a mad assassin has disappeared
        from the surface of the earth, but his spirit is immortal.</p>
    <quote>
        <lg>
            <l>—"a man, a ruler, and a sage;</l>
            <l>A truly worthy model of the age."</l>
        </lg>
    </quote>
</div>;

declare function local:transform($originals as node()*) {
    for $original in $originals
    return
        typeswitch ($original)
            case text() return $original
            case element(tei:div) return
                <div>{local:transform($original/node())}</div>
            case element(tei:p) return
                <p>{local:transform($original/node())}</p>
            case element(tei:quote) return
                <blockquote>{local:transform($original/node())}</blockquote>
            case element(tei:lg) return
                <p>{local:transform($original/node())}</p>
            case element(tei:l) return
                (local:transform($original/node()),
                 if ($original/following-sibling::tei:l) then <br/> else ())
            default return $original
};

local:transform($doc)
```

Each `case` handles a specific element type. The recursive call `local:transform($original/node())` processes all children, building up the output tree.

## Generating a Table of Contents

A more practical typeswitch example — generating an HTML table of contents from TEI document structure:

```xquery
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $text := <text xmlns="http://www.tei-c.org/ns/1.0">
    <div xml:id="ch1">
        <head>Chapter One</head>
        <div xml:id="ch1.1"><head>Introduction</head></div>
        <div xml:id="ch1.2">
            <head>Section 1</head>
            <div xml:id="ch1.2.1"><head>Subsection 1</head></div>
            <div xml:id="ch1.2.2"><head>Subsection 2</head></div>
        </div>
    </div>
    <div xml:id="ch2">
        <head>Chapter Two</head>
        <div xml:id="ch2.1"><head>Introduction</head></div>
        <div xml:id="ch2.2">
            <head>Section 1</head>
            <div xml:id="ch2.2.1"><head>Subsection 1</head></div>
        </div>
    </div>
</text>;

declare function local:toc($originals as node()*) {
    for $original in $originals
    return
        typeswitch ($original)
            case element(tei:text) return
                <nav>
                    <h2>Table of Contents</h2>
                    <ul>{local:toc($original/node())}</ul>
                </nav>
            case element(tei:div) return
                <li>
                    <a href="#{$original/@xml:id}">
                        {local:toc($original/tei:head)}
                    </a>
                    {if ($original/tei:div) then
                        <ul>{local:toc($original/tei:div)}</ul>
                     else ()}
                </li>
            case element(tei:head) return $original/string()
            case element() return local:toc($original/node())
            default return ()
};

local:toc($text)
```

## Higher-Order Functions and Partial Application

Functions can be passed as arguments and partially applied using `?` as a placeholder:

```xquery
declare function local:get-dates($name as xs:string?) as xs:integer* {
    (fn:replace($name, ".*(\d{4})-(\d{4}).", "$1 $2")
     => fn:tokenize(" "))
    ! xs:integer(.)
};

declare function local:is-seventeenth($dates as xs:integer*) as xs:boolean {
    ($dates[1] gt 1601 and $dates[1] lt 1700)
    or
    ($dates[2] gt 1601 and $dates[2] lt 1700)
};

let $check-dates :=
    function($name as xs:string?, $century as function(*)) as xs:boolean {
        let $dates := local:get-dates($name)
        return $century($dates)
    }
let $writers := (
    "Shakespeare (1564-1616)",
    "Milton (1608-1674)",
    "Dryden (1631-1700)",
    "Blake (1757-1827)",
    "Keats (1795-1821)"
)
return
    fn:filter($writers, $check-dates(?, local:is-seventeenth#1))
```

`$check-dates(?, local:is-seventeenth#1)` creates a new function with the century checker pre-filled. `fn:filter` then calls this function on each writer, keeping only those active in the 17th century.

## Partial Application with string-join

A simpler partial application example:

```xquery
let $join-with-comma := fn:string-join(?, ", ")
let $words := ("Mary", "Margaret", "Max")
return
    $join-with-comma($words)
```

`fn:string-join(?, ", ")` creates a new function that joins any sequence with commas.
