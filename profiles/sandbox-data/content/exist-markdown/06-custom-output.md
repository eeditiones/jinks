# Custom Output Formats

Since `md:parse()` produces a well-defined XML vocabulary, you can transform its output to any format using XQuery's `typeswitch` expression. This chapter demonstrates transforming markdown to TEI, Docbook, and other custom formats.

## Markdown to TEI

[TEI](https://tei-c.org/) (Text Encoding Initiative) is a standard XML vocabulary for scholarly texts. Here's a recursive typeswitch function that transforms parsed markdown to TEI:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:to-tei($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:document) return
                <tei:body>{ local:to-tei($node/node()) }</tei:body>
            case element(md:heading) return
                <tei:head n="{ $node/@level }">{ local:to-tei($node/node()) }</tei:head>
            case element(md:paragraph) return
                <tei:p>{ local:to-tei($node/node()) }</tei:p>
            case element(md:fenced-code) return
                <tei:code lang="{ $node/@language }">{ string($node) }</tei:code>
            case element(md:list) return
                <tei:list>{
                    if ($node/@type = "ordered") then
                        attribute rend { "ordered" }
                    else (),
                    local:to-tei($node/node())
                }</tei:list>
            case element(md:list-item) return
                <tei:item>{ local:to-tei($node/node()) }</tei:item>
            case element(md:blockquote) return
                <tei:quote>{ local:to-tei($node/node()) }</tei:quote>
            case element(md:emphasis) return
                <tei:hi>{ local:to-tei($node/node()) }</tei:hi>
            case element(md:strong) return
                <tei:hi rend="bold">{ local:to-tei($node/node()) }</tei:hi>
            case element(md:link) return
                <tei:ref target="{ $node/@href }">{ local:to-tei($node/node()) }</tei:ref>
            case element(md:image) return
                <tei:figure>
                    <tei:graphic url="{ $node/@src }"/>
                </tei:figure>
            case element(md:code) return
                <tei:code>{ string($node) }</tei:code>
            case text() return $node
            default return local:to-tei($node/node())
};

local:to-tei(md:parse("# Introduction

This is a **scholarly** text with a [reference](https://example.org).

> Knowledge is power.

1. First point
2. Second point

```xquery
(: A code example :)
doc('/db/data')//entry
```"))
```

## Markdown to HTML with Custom Classes

Apply custom CSS classes to the HTML output:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare function local:styled-html($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:document) return
                <div class="markdown-body">{ local:styled-html($node/node()) }</div>
            case element(md:heading) return
                element { "h" || $node/@level } {
                    attribute class { "section-heading level-" || $node/@level },
                    attribute id { replace(lower-case($node/string()), '\s+', '-') },
                    local:styled-html($node/node())
                }
            case element(md:paragraph) return
                <p class="body-text">{ local:styled-html($node/node()) }</p>
            case element(md:fenced-code) return
                <pre class="code-block">
                    <code class="language-{ $node/@language }">{ string($node) }</code>
                </pre>
            case element(md:list) return
                element { if ($node/@type = "ordered") then "ol" else "ul" } {
                    attribute class { "styled-list" },
                    local:styled-html($node/node())
                }
            case element(md:list-item) return
                <li>{ local:styled-html($node/node()) }</li>
            case element(md:strong) return
                <strong>{ local:styled-html($node/node()) }</strong>
            case element(md:emphasis) return
                <em>{ local:styled-html($node/node()) }</em>
            case element(md:link) return
                <a href="{ $node/@href }" class="external-link" target="_blank">{
                    local:styled-html($node/node())
                }</a>
            case element(md:code) return
                <code class="inline-code">{ string($node) }</code>
            case element(md:blockquote) return
                <blockquote class="pullquote">{ local:styled-html($node/node()) }</blockquote>
            case text() return $node
            default return local:styled-html($node/node())
};

local:styled-html(md:parse("# Getting Started

Install the package via the **dashboard** or use `xst`:

> The markdown module supports full CommonMark and GFM.

- Parse to XML with `md:parse()`
- Render to HTML with `md:to-html()`
- Round-trip with `md:serialize()`

See [the documentation](https://github.com/eXist-db/exist-markdown) for more."))
```

## Markdown to JSON-like XML

Transform markdown into a JSON-friendly XML structure for API responses:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare function local:to-api($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:document) return
                <document>{ local:to-api($node/node()) }</document>
            case element(md:heading) return
                <block type="heading" level="{ $node/@level }">
                    <text>{ $node/string() }</text>
                </block>
            case element(md:paragraph) return
                <block type="paragraph">
                    <text>{ $node/string() }</text>
                </block>
            case element(md:fenced-code) return
                <block type="code" language="{ $node/@language }">
                    <text>{ string($node) }</text>
                </block>
            case element(md:list) return
                <block type="list" style="{ $node/@type }">
                    { local:to-api($node/node()) }
                </block>
            case element(md:list-item) return
                <item>{ $node/string() }</item>
            default return ()
};

local:to-api(md:parse("# API Response

This gets transformed to a structured format.

```json
{""key"": ""value""}
```

- Item A
- Item B
- Item C"))
```

## Pipeline: Parse, Transform, Serialize

Combine parsing, transformation, and serialization for a markdown-to-markdown pipeline. This example converts all headings to title case:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

declare function local:title-case($text as xs:string) as xs:string {
    string-join(
        for $word in tokenize($text, '\s+')
        return
            upper-case(substring($word, 1, 1)) || lower-case(substring($word, 2)),
        ' '
    )
};

declare function local:transform($nodes as node()*) as node()* {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(md:heading) return
                element { node-name($node) } {
                    $node/@*,
                    text { local:title-case($node/string()) }
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    local:transform($node/node())
                }
            default return $node
};

let $input := "# getting started with exist-db

## querying xml data

Some content here.

## building web applications

More content."

return md:serialize(local:transform(md:parse($input)))
```
