# Round-Tripping

The `md:serialize()` function converts `md:*` XML nodes back to CommonMark markdown text. Combined with `md:parse()`, this enables round-trip processing: parse markdown to XML, transform the XML, then serialize back to markdown.

## Basic Round-Trip

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $input := "# Hello World

A paragraph with **bold** and *italic* text."

let $xml := md:parse($input)
let $output := md:serialize($xml)

return $output
```

## Verifying Round-Trip Fidelity

Parse the serialized output again and compare structure:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $input := "# Features

- **Bold** text
- *Italic* text
- `Code` spans
- ~~Strikethrough~~"

let $first := md:parse($input)
let $roundtripped := md:parse(md:serialize($first))

return
    map {
        "original-headings": count($first//md:heading),
        "roundtrip-headings": count($roundtripped//md:heading),
        "original-items": count($first//md:list-item),
        "roundtrip-items": count($roundtripped//md:list-item),
        "structure-preserved": deep-equal(
            $first//md:heading/@level,
            $roundtripped//md:heading/@level
        )
    }
```

## Code Block Round-Trip

Fenced code blocks preserve their language label and content through round-trips:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $input := '```xquery
for $i in 1 to 10
return
    map { "n": $i, "square": $i * $i }
```'

return md:serialize(md:parse($input))
```

## Table Round-Trip

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $input := "| Language | Type System | Paradigm |
| :--- | :---: | ---: |
| XQuery | Static | Functional |
| XSLT | Static | Declarative |
| JavaScript | Dynamic | Multi |"

return md:serialize(md:parse($input))
```

## Transforming Before Serializing

Parse markdown, modify the XML, then serialize. Here we promote all headings by one level:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare function local:promote-headings($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:heading) return
                element { node-name($node) } {
                    attribute level { max((1, xs:integer($node/@level) - 1)) },
                    $node/node()
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    local:promote-headings($node/node())
                }
            default return $node
};

let $input := "## Section A

Some text.

### Subsection A.1

More text.

## Section B

Final text."

let $parsed := md:parse($input)
let $promoted := local:promote-headings($parsed)

return md:serialize($promoted)
```

## Filtering Content

Remove all code blocks from a document:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare function local:remove-code($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:fenced-code) return ()
            case element(md:code-block) return ()
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    local:remove-code($node/node())
                }
            default return $node
};

let $input := "# Guide

Read this paragraph.

```xquery
(: this code will be removed :)
1 + 1
```

Another paragraph.

```python
# this too
print('gone')
```

The end."

return md:serialize(local:remove-code(md:parse($input)))
```
