# Selective Rendering

The `md:to-html()` function also accepts `md:*` XML nodes from `md:parse()`. This enables *selective rendering* — rendering some elements as HTML while handling others with custom logic.

## Parse Then Render

The two-step approach — parse first, then render — lets you inspect or transform the markdown structure before producing HTML:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $doc := md:parse("# Title

A paragraph with **bold** text.

```xquery
let $x := 1
```")

(: Render just the heading :)
return md:to-html($doc//md:heading)
```

## Rendering Individual Blocks

You can render any combination of parsed nodes. Here we render everything except code blocks:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $doc := md:parse("# Tutorial

Learn to use `md:parse()`.

```xquery
md:parse('# Hello')
```

## Next Steps

Try the other functions too.")

return
    for $node in $doc/md:document/*
    return
        if ($node/self::md:fenced-code) then
            <div class="skipped">[Code block: { $node/@language/string() }]</div>
        else
            md:to-html($node)
```

## Extracting Metadata

Use `md:parse()` to extract structured information from markdown documents:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $doc := md:parse("# API Reference

## md:parse

Parses markdown to XML.

## md:to-html

Renders to HTML.

## md:serialize

Round-trips back to markdown.")

return
    <toc>{
        for $heading in $doc//md:heading
        return
            <entry level="{ $heading/@level }">{ $heading/string() }</entry>
    }</toc>
```

## Extracting Code Blocks by Language

Find all code blocks of a specific language — useful for documentation tools, test extraction, or the Sandbox's interactive editors:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $doc := md:parse('# Examples

A JavaScript example:

```javascript
console.log("Hello");
```

An XQuery example:

```xquery
"Hello from XQuery"
```

A Python example:

```python
print("Hello")
```')

return
    <code-blocks>{
        for $code in $doc//md:fenced-code
        return
            <block language="{ $code/@language }">{ $code/string() }</block>
    }</code-blocks>
```

## Counting Elements

Analyze the structure of a markdown document:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $doc := md:parse("# Main Title

First paragraph.

## Section A

Second paragraph with **bold**.

- Item 1
- Item 2
- Item 3

## Section B

> A quote.

| A | B |
| --- | --- |
| 1 | 2 |")

return
    map {
        "headings": count($doc//md:heading),
        "paragraphs": count($doc//md:paragraph),
        "list-items": count($doc//md:list-item),
        "tables": count($doc//md:table),
        "blockquotes": count($doc//md:blockquote)
    }
```
