# Parsing Basics

The `md:parse()` function converts a CommonMark/GFM markdown string into an XML document using the `md:*` element vocabulary. This structured representation preserves all semantic information from the source markdown.

## Simple Parsing

Parse a heading and paragraph:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("# Hello World

This is a paragraph with **bold** and *italic* text.")
```

The result is an XML document rooted at `md:document`, with child elements for each block and inline element.

## Headings

ATX-style headings (`#` through `######`) are parsed with their level preserved in the `@level` attribute:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6")
```

## Inline Formatting

Markdown inline syntax maps to `md:strong`, `md:emphasis`, `md:code`, and `md:strikethrough` elements:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("Text with **bold**, *italic*, `code`, and ~~strikethrough~~.")
```

## Fenced Code Blocks

Fenced code blocks preserve the language label in the `@language` attribute — critical for syntax highlighting and the Sandbox's interactive code editors:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse('```xquery
for $i in 1 to 5
return
    <item n="{$i}">{ $i * $i }</item>
```')
```

Notice that curly braces, angle brackets, and quotes inside code blocks are preserved exactly as written.

## Links and Images

Links become `md:link` elements with `@href` and optional `@title`. Images become `md:image` with `@src`, `@alt`, and `@title`:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse('Visit [eXist-db](https://exist-db.org "eXist Homepage") for more.

![Logo](https://exist-db.org/exist/apps/homepage/resources/img/existdb.gif "eXist-db Logo")')
```

## Lists

Bullet lists, ordered lists, nested lists, and task lists are all supported:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("- Buy milk
- Drink it
- Be happy")
```

Ordered lists use numbered markers:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("1. First
2. Second
    - Nested bullet
    - Another nested
3. Third")
```

Task lists use `[x]` and `[ ]` markers:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("- [x] Implement parser
- [x] Write tests
- [ ] Ship it")
```

## Tables

GFM tables with optional column alignment:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("| Feature | Status | Priority |
| :--- | :---: | ---: |
| Tables | Done | High |
| Task lists | Done | Medium |
| Autolinks | Done | Low |")
```

## Block Quotes and Thematic Breaks

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("> The only way to do great work is to love what you do.
>
> — Steve Jobs

---

A paragraph after the thematic break.")
```
