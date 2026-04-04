# HTML Rendering

The `md:to-html()` function renders markdown directly to HTML nodes. Pass it a markdown string for one-step conversion.

## Basic Rendering

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:to-html("## Features

The markdown module supports:

- **Bold** and *italic* text
- `Inline code` and fenced code blocks
- [Links](https://exist-db.org) and images
- GFM tables and task lists")
```

## Code Blocks with Language Classes

Fenced code blocks render as `<pre><code class="language-...">`, ready for syntax highlighting libraries like Prism.js or highlight.js:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:to-html('```xquery
let $greeting := "Hello from eXist-db"
return
    <message>{ $greeting }</message>
```')
```

## Tables

GFM tables render with proper `<thead>`, `<tbody>`, `<th>`, and `<td>` elements. Column alignment is applied via inline `style` attributes:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:to-html("| Left | Center | Right |
| :--- | :---: | ---: |
| apples | 12 | $1.50 |
| oranges | 8 | $2.00 |
| **total** | **20** | **$3.50** |")
```

## Task Lists

Task lists render with checkbox inputs:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:to-html("- [x] Parse markdown to XML
- [x] Render HTML
- [x] Round-trip serialization
- [ ] World domination")
```

## Rendering a Full Document

Combine multiple markdown features in a single document:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:to-html("# Project Status

We've completed the **first milestone**. Here's the summary:

> All tests passing. Ready for review.

## Completed Features

| Feature | Tests |
| --- | --- |
| Parsing | 20 |
| Rendering | 8 |
| Round-trip | 12 |

See the [documentation](https://github.com/eXist-db/exist-markdown) for details.

```xquery
(: This code block is rendered, not executed :)
md:parse($input) => md:to-html()
```")
```
