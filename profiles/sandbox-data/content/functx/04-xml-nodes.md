# XML Node Functions

FunctX provides functions for inspecting and transforming XML nodes — adding attributes, removing elements, changing namespaces, and navigating trees.

## Adding Attributes

```xquery
import module namespace functx = "http://www.functx.com";

let $elem := <book>XQuery for Humanists</book>
return (
    functx:add-attributes($elem, xs:QName('isbn'), '978-1623498290'),
    functx:add-attributes($elem,
        (xs:QName('isbn'), xs:QName('year')),
        ('978-1623498290', '2020'))
)
```

**Expected:** `<book isbn="978-1623498290">XQuery for Humanists</book>` and `<book isbn="978-1623498290" year="2020">XQuery for Humanists</book>`

## Removing Elements

`functx:remove-elements-deep()` recursively removes named elements from a tree:

```xquery
import module namespace functx = "http://www.functx.com";

let $doc :=
    <article>
        <title>Sample</title>
        <body>
            <p>Text with <note>a footnote</note> inline.</p>
            <p>More text with <note>another note</note>.</p>
        </body>
    </article>
return (
    functx:remove-elements-deep($doc, 'note'),
    functx:remove-elements-deep($doc, ('note', 'title'))
)
```

## Changing Namespaces

Transform all elements to a new namespace:

```xquery
import module namespace functx = "http://www.functx.com";

let $doc :=
    <bar:article xmlns:bar="http://bar">
        <bar:title>Hello</bar:title>
        <bar:body>World</bar:body>
    </bar:article>
return (
    functx:change-element-ns-deep($doc, 'http://www.tei-c.org/ns/1.0', 'tei'),
    functx:change-element-ns-deep($doc, 'http://www.w3.org/1999/xhtml', '')
)
```

## Inspecting Tree Structure

```xquery
import module namespace functx = "http://www.functx.com";

let $doc :=
    <authors>
        <author>
            <fName>Kate</fName>
            <lName>Jones</lName>
        </author>
        <author>
            <fName>John</fName>
            <lName>Doe</lName>
        </author>
    </authors>
return (
    <paths>{
        for $leaf in functx:leaf-elements($doc)
        return
            <leaf path="{functx:path-to-node($leaf)}"
                  depth="{functx:depth-of-node($leaf)}">
                {$leaf/string()}
            </leaf>
    }</paths>
)
```

**Expected:** Each leaf element with its path (e.g., `authors/author/fName`) and depth (e.g., `3`).

## Atomic Type Inspection

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:atomic-type(42),
    functx:atomic-type('hello'),
    functx:atomic-type(true()),
    functx:atomic-type(xs:date('2024-01-01'))
)
```

**Expected:** `"xs:integer"`, `"xs:string"`, `"xs:boolean"`, `"xs:date"`
