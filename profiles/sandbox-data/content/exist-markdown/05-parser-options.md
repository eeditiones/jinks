# Parser Options

The `md:parse()` and `md:to-html()` functions accept an optional second parameter — an XQuery map — to configure the parser profile and extensions.

## Default Behavior

By default, the parser uses the GitHub-flavored profile with all extensions enabled (tables, strikethrough, task lists, autolinks):

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("~~struck~~ and https://exist-db.org and | A |
| --- |
| 1 |")
```

## Strict CommonMark

Disable all GFM extensions for strict CommonMark parsing. Tables, strikethrough, and autolinks will be treated as plain text:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("~~not struck~~ and | not | a | table |
| --- | --- | --- |
| just | plain | text |",
    map { "profile": "commonmark", "extensions": () })
```

Compare this to the default behavior above — the same input produces very different output.

## Selective Extensions

Enable only specific extensions. Here we enable tables but not strikethrough:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("| Feature | Status |
| --- | --- |
| Tables | Enabled |

~~This is NOT struck through~~ because the strikethrough extension is disabled.",
    map { "extensions": ("tables") })
```

## Multiple Extensions

Pass a sequence of extension names:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

md:parse("- [x] Task lists work
- [ ] Strikethrough: ~~deleted~~
- [ ] Tables: see below

| Yes | No |
| --- | --- |
| ✓ | ✗ |",
    map { "extensions": ("tables", "tasklist", "strikethrough") })
```

## Options with md:to-html

The same options map works with `md:to-html()` for direct HTML rendering:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

(: CommonMark rendering — no GFM extensions :)
md:to-html("~~plain text~~

| not | a | table |",
    map { "profile": "commonmark", "extensions": () })
```

## Comparing Profiles

Parse the same input with different profiles to see how they differ:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

let $input := "- Item 1

    Continuation paragraph

- Item 2"

return
    map {
        "github": md:serialize(md:parse($input, map { "profile": "github" })),
        "commonmark": md:serialize(md:parse($input, map { "profile": "commonmark" })),
        "fixed-indent": md:serialize(md:parse($input, map { "profile": "fixed-indent" }))
    }
```

## Available Profiles

The full list of supported profiles:

```xquery
import module namespace md = "http://exist-db.org/xquery/markdown";

(: Try each profile on the same input :)
let $input := "# Test

A paragraph.

- Item 1
- Item 2"

for $profile in ("commonmark", "github", "kramdown", "markdown", "pegdown", "fixed-indent", "multi-markdown")
return
    map {
        "profile": $profile,
        "headings": count(md:parse($input, map { "profile": $profile })//md:heading),
        "paragraphs": count(md:parse($input, map { "profile": $profile })//md:paragraph),
        "list-items": count(md:parse($input, map { "profile": $profile })//md:list-item)
    }
```
