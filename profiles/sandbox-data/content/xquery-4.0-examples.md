# XQuery 4.0 Examples

A collection of runnable examples demonstrating XQuery 4.0 features available in eXist-db. Each fenced XQuery block below becomes an executable cell in the Sandbox notebook.

## Basics

### Hello World

The simplest XQuery expression:

```xquery
"Hello, World!"
```

### Arithmetic

XQuery supports standard arithmetic operators:

```xquery
2 + 3, 10 div 3, 7 mod 2, 2 ** 8
```

### String Concatenation

Use the `||` operator or `concat()` function:

```xquery
"Hello" || ", " || "World!",
concat("XQuery ", "4.0")
```

### Sequences

Sequences are the fundamental data structure in XQuery:

```xquery
(1, 2, 3, 4, 5),
1 to 10,
("a", "b", "c")
```

### Sequence Operations

```xquery
let $seq := 1 to 10
return (
    head($seq),
    tail($seq),
    count($seq),
    sum($seq),
    avg($seq),
    min($seq),
    max($seq)
)
```

## FLWOR Expressions

### Basic For-Return

```xquery
for $i in 1 to 5
return $i * $i
```

### For with Let and Where

```xquery
for $n in 1 to 20
let $square := $n * $n
where $n mod 2 = 0
return <even n="{$n}" square="{$square}"/>
```

### Order By

```xquery
let $words := ("banana", "apple", "cherry", "date")
for $w in $words
order by $w
return $w
```

### Group By

```xquery
let $items := (
    map { "category": "fruit", "name": "apple" },
    map { "category": "vegetable", "name": "carrot" },
    map { "category": "fruit", "name": "banana" },
    map { "category": "vegetable", "name": "pea" }
)
for $item in $items
group by $cat := $item?category
return $cat || ": " || string-join(for $i in $item return $i?name, ", ")
```

### Window Clause

Tumbling windows partition a sequence into non-overlapping groups:

```xquery
for tumbling window $w in 1 to 10
    start when true()
    end at $pos when $pos mod 3 = 0
return <group>{$w}</group>
```

### Sliding Window

Sliding windows produce overlapping groups:

```xquery
for sliding window $w in 1 to 6
    start at $s when true()
    end at $e when $e - $s = 2
return <window>{$w}</window>
```

## Conditional and Switch

### If-Then-Else

```xquery
for $n in 1 to 10
return
    if ($n mod 15 = 0) then "FizzBuzz"
    else if ($n mod 3 = 0) then "Fizz"
    else if ($n mod 5 = 0) then "Buzz"
    else $n
```

### Switch Expression

```xquery
for $day in ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
return
    switch ($day)
        case "Sat" case "Sun" return $day || ": weekend"
        default return $day || ": weekday"
```

## Functions

### Inline Functions (Lambdas)

```xquery
let $double := function($x) { $x * 2 }
let $add := function($a, $b) { $a + $b }
return (
    $double(21),
    $add(20, 22)
)
```

### Higher-Order Functions

```xquery
let $numbers := 1 to 10
return (
    for-each($numbers, function($n) { $n * $n }),
    filter($numbers, function($n) { $n mod 2 = 0 }),
    fold-left($numbers, 0, function($acc, $n) { $acc + $n })
)
```

### Function Composition

```xquery
let $double := function($x) { $x * 2 }
let $add-one := function($x) { $x + 1 }
let $double-then-add := function($x) { $add-one($double($x)) }
for $i in 1 to 5
return $double-then-add($i)
```

### Named Function References

```xquery
let $nums := (3, 1, 4, 1, 5, 9, 2, 6)
return (
    sort($nums),
    sort($nums, (), function($n) { -$n })
)
```

### Recursive Functions

```xquery
let $factorial := function($self, $n) {
    if ($n le 1) then 1
    else $n * $self($self, $n - 1)
}
return for $i in 1 to 10
return $i || "! = " || $factorial($factorial, $i)
```

## Maps

### Map Construction

```xquery
let $person := map {
    "name": "Ada Lovelace",
    "born": 1815,
    "field": "Computing"
}
return (
    $person?name,
    $person?born,
    map:keys($person)
)
```

### Map Operations

```xquery
let $m := map { "a": 1, "b": 2, "c": 3 }
return (
    map:put($m, "d", 4)?d,
    map:remove($m, "a") => map:keys(),
    map:contains($m, "b"),
    map:size($m)
)
```

### Map Merge

```xquery
let $defaults := map { "color": "blue", "size": 12, "bold": false() }
let $overrides := map { "color": "red", "bold": true() }
return map:merge(($defaults, $overrides))
```

### Map For-Each

```xquery
let $scores := map { "Alice": 95, "Bob": 87, "Carol": 92 }
return map:for-each($scores, function($name, $score) {
    $name || ": " || (if ($score >= 90) then "A" else "B")
})
```

## Arrays

### Array Construction

```xquery
let $arr := [1, 2, 3, 4, 5]
return (
    $arr?1,
    $arr?3,
    array:size($arr),
    array:head($arr),
    array:tail($arr)
)
```

### Array Operations

```xquery
let $arr := ["hello", "world"]
return (
    array:append($arr, "!"),
    array:join(($arr, ["foo", "bar"])),
    array:reverse($arr),
    array:flatten(([1, [2, 3]], [4, 5]))
)
```

### Array For-Each and Filter

```xquery
let $nums := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
return (
    array:for-each($nums, function($n) { $n * $n }),
    array:filter($nums, function($n) { $n mod 2 = 0 }),
    array:fold-left($nums, 0, function($acc, $n) { $acc + $n })
)
```

## Strings

### String Functions

```xquery
let $s := "  Hello, XQuery World!  "
return (
    upper-case($s),
    lower-case($s),
    normalize-space($s),
    string-length(normalize-space($s)),
    substring($s, 3, 5),
    contains($s, "XQuery"),
    starts-with(normalize-space($s), "Hello"),
    ends-with(normalize-space($s), "World!")
)
```

### String Join and Tokenize

```xquery
let $words := ("XQuery", "is", "powerful")
return (
    string-join($words, " "),
    tokenize("one,two,three", ","),
    string-join(for $w in $words return upper-case($w), "-")
)
```

### Regular Expressions

```xquery
let $text := "Phone: 555-1234, Fax: 555-5678"
return (
    matches($text, "\d{3}-\d{4}"),
    replace($text, "\d{3}-\d{4}", "XXX-XXXX"),
    analyze-string($text, "(\d{3})-(\d{4})")
)
```

### String Constructors

XQuery 3.1 string constructors for building strings with embedded expressions:

```xquery
let $name := "World"
let $n := 42
return ``[Hello `{$name}`! The answer is `{$n}`. Today is `{current-date()}`.]``
```

## XML Construction

### Direct Element Construction

```xquery
<library>
    {
        for $i in 1 to 3
        return
            <book id="{$i}">
                <title>Book {$i}</title>
                <year>{2020 + $i}</year>
            </book>
    }
</library>
```

### Computed Constructors

```xquery
let $tag := "item"
let $attr := "id"
return
    element { $tag } {
        attribute { $attr } { "123" },
        text { "Dynamic content" }
    }
```

### Namespaces

```xquery
<tei:TEI xmlns:tei="http://www.tei-c.org/ns/1.0">
    <tei:teiHeader>
        <tei:fileDesc>
            <tei:titleStmt>
                <tei:title>Sample Document</tei:title>
            </tei:titleStmt>
        </tei:fileDesc>
    </tei:teiHeader>
</tei:TEI>
```

### XSLT-style Transformation

Transform XML using typeswitch:

```xquery
declare function local:transform($node as node()) {
    typeswitch ($node)
        case element(item) return
            <li>{for $child in $node/node() return local:transform($child)}</li>
        case element(list) return
            <ul>{for $child in $node/node() return local:transform($child)}</ul>
        case element(bold) return
            <strong>{$node/text()}</strong>
        default return $node
};

local:transform(
    <list>
        <item>First <bold>item</bold></item>
        <item>Second item</item>
        <item>Third item</item>
    </list>
)
```

## XPath Axes

### Working with Axes

```xquery
let $doc :=
    <root>
        <a>
            <b id="1">
                <c>text1</c>
            </b>
            <b id="2">
                <c>text2</c>
                <d>text3</d>
            </b>
        </a>
    </root>
return (
    <children>{$doc/a/b}</children>,
    <descendants>{$doc//c}</descendants>,
    <following>{$doc//b[@id="1"]/following-sibling::b}</following>,
    <attributes>{$doc//b/@id}</attributes>
)
```

### Predicates and Positional Access

```xquery
let $items :=
    <list>
        <item type="a" priority="3">Alpha</item>
        <item type="b" priority="1">Beta</item>
        <item type="a" priority="2">Gamma</item>
        <item type="b" priority="4">Delta</item>
    </list>
return (
    $items/item[@type="a"],
    $items/item[position() <= 2],
    $items/item[last()],
    $items/item[@priority > 2]
)
```

## Quantified Expressions

### Some and Every

```xquery
let $nums := (2, 4, 6, 8, 10)
return (
    some $n in $nums satisfies $n > 8,
    every $n in $nums satisfies $n mod 2 = 0,
    some $n in $nums satisfies $n = 5,
    every $n in $nums satisfies $n < 20
)
```

## Try-Catch

### Error Handling

```xquery
try {
    1 div 0
} catch * {
    "Caught error: " || $err:description ||
    " (code: " || $err:code || ")"
}
```

### Custom Errors

```xquery
try {
    let $age := -5
    return
        if ($age < 0) then
            error(xs:QName("app:INVALID_AGE"), "Age cannot be negative: " || $age)
        else
            "Age: " || $age
} catch app:INVALID_AGE {
    "Validation error: " || $err:description
}
```

## Dates and Times

### Date Functions

```xquery
let $now := current-dateTime()
let $today := current-date()
return (
    "Now: " || $now,
    "Today: " || $today,
    "Year: " || year-from-date($today),
    "Month: " || month-from-date($today),
    "Day: " || day-from-date($today),
    "Day of week: " || format-date($today, "[FNn]")
)
```

### Date Arithmetic

```xquery
let $start := xs:date("2024-01-15")
let $end := xs:date("2024-12-31")
let $duration := $end - $start
return (
    "Start: " || $start,
    "End: " || $end,
    "Duration: " || $duration,
    "Days: " || days-from-duration($duration),
    "Plus 30 days: " || $start + xs:dayTimeDuration("P30D")
)
```

## JSON Integration

### JSON Parsing and Serialization

```xquery
let $json-str := '{"name": "Ada", "skills": ["math", "logic", "programming"]}'
let $parsed := parse-json($json-str)
return (
    $parsed?name,
    $parsed?skills?*,
    serialize($parsed, map { "method": "json", "indent": true() })
)
```

### Building JSON from XML

```xquery
let $books :=
    <books>
        <book><title>XQuery</title><year>2024</year></book>
        <book><title>XSLT</title><year>2023</year></book>
    </books>
return
    array {
        for $book in $books/book
        return map {
            "title": string($book/title),
            "year": xs:integer($book/year)
        }
    }
```

## Serialization

### Adaptive Output

```xquery
let $mixed := (
    42,
    "hello",
    <element attr="val">content</element>,
    map { "key": "value" },
    [1, 2, 3],
    true()
)
for $item in $mixed
return serialize($item, map { "method": "adaptive" }) || " (" || string(type($item)) || ")"
```

## eXist-db Functions

### Database Queries

```xquery
(: List collections under /db :)
xmldb:get-child-collections("/db")
```

### UUID Generation

```xquery
for $i in 1 to 5
return util:uuid()
```

### System Information

```xquery
map {
    "eXist version": system:get-version(),
    "build": system:get-build(),
    "revision": system:get-revision(),
    "Java version": util:system-property("java.version"),
    "OS": util:system-property("os.name")
}
```

### Inspecting Functions

```xquery
let $modules := util:registered-modules()
return
    <modules count="{count($modules)}">
    {
        for $ns in subsequence(sort($modules), 1, 20)
        return <module uri="{$ns}"/>
    }
    </modules>
```

## Advanced Patterns

### Pipeline with Arrow Operator

```xquery
"  Hello, World!  "
=> normalize-space()
=> upper-case()
=> tokenize("\s+")
=> string-join("-")
```

### Recursive Descent

```xquery
declare function local:flatten($items) {
    for $item in $items
    return
        if ($item instance of array(*)) then
            local:flatten($item?*)
        else
            $item
};

local:flatten([1, [2, [3, [4, 5]], 6], [7, 8]])
```

### Fibonacci with Fold

```xquery
let $n := 15
return
    fold-left(1 to $n - 2, [0, 1], function($acc, $_) {
        let $next := $acc?(array:size($acc) - 1) + $acc?(array:size($acc))
        return array:append($acc, $next)
    })
```

### Generating HTML Tables

```xquery
let $data := (
    map { "name": "Alice", "age": 30, "city": "London" },
    map { "name": "Bob", "age": 25, "city": "Paris" },
    map { "name": "Carol", "age": 35, "city": "Berlin" }
)
let $keys := ("name", "age", "city")
return
    <table border="1">
        <tr>{for $k in $keys return <th>{$k}</th>}</tr>
        {
            for $row in $data
            return
                <tr>{for $k in $keys return <td>{$row($k)}</td>}</tr>
        }
    </table>
```

### Simple Templating Engine

```xquery
let $template := "Dear {{name}}, your order #{{order}} is {{status}}."
let $vars := map {
    "name": "Alice",
    "order": "12345",
    "status": "shipped"
}
return
    fold-left(map:keys($vars), $template, function($text, $key) {
        replace($text, "\{\{" || $key || "\}\}", $vars($key))
    })
```

### Caesar Cipher

```xquery
let $encrypt := function($text, $shift) {
    string-join(
        for $cp in string-to-codepoints(upper-case($text))
        return
            if ($cp >= 65 and $cp <= 90) then
                codepoints-to-string(($cp - 65 + $shift) mod 26 + 65)
            else
                codepoints-to-string($cp)
    )
}
return (
    $encrypt("Hello World", 3),
    $encrypt($encrypt("Hello World", 3), 23)  (: decrypt with 26 - 3 = 23 :)
)
```

### ROT13

```xquery
let $rot13 := function($s) {
    string-join(
        for $c in string-to-codepoints($s)
        return codepoints-to-string(
            if ($c >= 65 and $c <= 90) then ($c - 65 + 13) mod 26 + 65
            else if ($c >= 97 and $c <= 122) then ($c - 97 + 13) mod 26 + 97
            else $c
        )
    )
}
return (
    $rot13("Hello, World!"),
    $rot13($rot13("Hello, World!"))
)
```

### Set Operations with Sequences

```xquery
let $a := (1, 2, 3, 4, 5)
let $b := (3, 4, 5, 6, 7)
return (
    "Union: " || string-join(distinct-values(($a, $b)) ! string(.), ", "),
    "Intersection: " || string-join($a[. = $b] ! string(.), ", "),
    "A minus B: " || string-join($a[not(. = $b)] ! string(.), ", ")
)
```

### Simple Map Operator (!)

The `!` operator applies an expression to each item in a sequence:

```xquery
(1 to 10) ! (. * .) ,
("hello", "world") ! upper-case(.) ,
(1 to 5) ! ("Item " || .)
```

### Generating a Multiplication Table

```xquery
<table border="1">
    <tr>
        <th>x</th>
        {for $i in 1 to 10 return <th>{$i}</th>}
    </tr>
    {
        for $row in 1 to 10
        return
            <tr>
                <th>{$row}</th>
                {for $col in 1 to 10 return <td>{$row * $col}</td>}
            </tr>
    }
</table>
```
