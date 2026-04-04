# Find All References

The `lsp:references()` function finds every usage of a symbol — every call site for a function, every read of a variable. This is the "Find All References" action in editors.

## Finding all calls to a function

Click on any call to `local:greet` and find them all — including the declaration:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare function local:greet($name as xs:string) as xs:string {
    "Hello, " || $name
};
local:greet("Alice"),
local:greet("Bob"),
local:greet("Carol")'

return lsp:references($code, 3, 7)
```

## Finding all reads of a variable

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare variable $local:multiplier := 10;
$local:multiplier * 2,
$local:multiplier * 3,
$local:multiplier * 4'

return lsp:references($code, 1, 5)
```

## Counting usages

Useful for detecting dead code — functions or variables that are declared but never called:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare function local:used() { "I am called" };
declare function local:unused() { "Nobody calls me" };
declare variable $local:active := local:used();
$local:active'

let $symbols := lsp:symbols($code)

return array:for-each($symbols, function($sym) {
    let $refs := lsp:references($code, $sym?line, $sym?column)
    return map {
        "name": $sym?name,
        "references": array:size($refs),
        "status": if (array:size($refs) <= 1) then "potentially unused" else "active"
    }
})
```

## No symbol returns empty

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $refs := lsp:references("1 + 2", 0, 2)
return "references found: " || array:size($refs)
```
