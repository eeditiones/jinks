# Hover Information

The `lsp:hover()` function returns information about the symbol at a given position — the tooltip you see when you hover over a function call or variable reference in an editor.

## Hovering over a built-in function

Position is 0-based. `fn:count` starts at line 0, column 0:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

lsp:hover("fn:count((1,2,3))", 0, 3)
```

The result contains `contents` (the signature and documentation) and `kind` (`"function"` or `"variable"`).

## Hovering over a user-defined function

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare function local:add($a as xs:integer, $b as xs:integer) as xs:integer {
    $a + $b
};
local:add(1, 2)'

return lsp:hover($code, 3, 7)
```

## Hovering over a variable reference

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare variable $local:greeting := "hello";
$local:greeting'

return lsp:hover($code, 1, 5)
```

## Empty positions return empty

If there's no symbol at the given position (e.g., over whitespace or an operator), you get an empty sequence:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $result := lsp:hover("1 + 2", 0, 2)
return if (empty($result)) then "no symbol at this position" else $result
```

## Building a documentation lookup

You can combine hover with completions to build a simple function reference:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

(: Generate a hover-able expression for each fn: function we want to document :)
for $fn in ("fn:count(1)", "fn:string-join(('a','b'), ',')", "fn:tokenize('a,b', ',')")
let $hover := lsp:hover($fn, 0, 3)
where exists($hover)
return map {
    "function": $fn,
    "signature": substring-before($hover?contents, "&#10;"),
    "description": substring-after($hover?contents, "&#10;&#10;")
}
```
