# Completions

The `lsp:completions()` function returns all completion items available in the context of an XQuery expression. This is what powers autocomplete in editors — the dropdown that appears as you type.

## Built-in functions are always available

Even with an empty expression, you get all built-in functions and keywords:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $completions := lsp:completions("")
return map {
    "total": array:size($completions),
    "sample": array:subarray($completions, 1, 3)
}
```

## Finding a specific function

Each completion item has `label`, `kind`, `detail`, `documentation`, and `insertText`:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $completions := lsp:completions("")
let $count := array:filter($completions, function($c) { $c?label = "fn:count#1" })
return $count(1)
```

## Keyword completions

XQuery keywords (`let`, `for`, `return`, `if`, etc.) are included with kind 14:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $completions := lsp:completions("")
let $keywords := array:filter($completions, function($c) { $c?kind = 14 })
return map {
    "count": array:size($keywords),
    "samples": array:for-each(array:subarray($keywords, 1, 10), function($k) { $k?label })
}
```

## User-declared symbols appear too

When the expression compiles, user-declared functions and variables join the completion list:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare variable $local:config := map { "debug": true() };
declare function local:process($input as xs:string) as xs:string {
    upper-case($input)
};
local:process("test")'

let $completions := lsp:completions($code)
let $user := array:filter($completions, function($c) {
    starts-with($c?label, "local:") or starts-with($c?label, "$local:")
})
return $user
```

## Exploring module namespaces

You can discover what functions are available in specific module namespaces:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $completions := lsp:completions("")
for $prefix in ("fn", "map", "array", "math", "util")
let $matches := array:filter($completions, function($c) {
    starts-with($c?label, $prefix || ":")
})
order by $prefix
return $prefix || ": " || array:size($matches) || " functions"
```
