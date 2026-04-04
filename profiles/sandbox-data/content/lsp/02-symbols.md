# Document Symbols

The `lsp:symbols()` function extracts all function and variable declarations from an XQuery expression. This powers the outline panel in editors — the tree of functions and variables you see in a sidebar.

## Extracting function declarations

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare function local:greet($name as xs:string) as xs:string {
    "Hello, " || $name
};
declare function local:farewell($name as xs:string) as xs:string {
    "Goodbye, " || $name
};
local:greet("world")'

return lsp:symbols($code)
```

Each symbol map contains `name` (e.g., `local:greet#1`), `kind` (12 for functions, 13 for variables), `line`, `column`, and `detail` (the full signature).

## Variable declarations

Global variable declarations are also extracted:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare variable $local:greeting as xs:string := "hello";
declare variable $local:count as xs:integer := 42;
$local:greeting || " " || $local:count'

return lsp:symbols($code)
```

## Mixed declarations

A realistic module with both functions and variables:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare variable $local:base-url := "https://example.com";
declare variable $local:timeout as xs:integer := 30;

declare function local:build-url($path as xs:string) as xs:string {
    $local:base-url || "/" || $path
};

declare function local:fetch($path as xs:string, $method as xs:string) as map(*) {
    map { "url": local:build-url($path), "method": $method }
};

local:fetch("api/data", "GET")'

let $symbols := lsp:symbols($code)
return map {
    "total": array:size($symbols),
    "functions": array:size(array:filter($symbols, function($s) { $s?kind = 12 })),
    "variables": array:size(array:filter($symbols, function($s) { $s?kind = 13 })),
    "names": array:for-each($symbols, function($s) { $s?name })
}
```

## Handling invalid code

If the expression can't be compiled, `lsp:symbols()` returns an empty array rather than throwing an error:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

array:size(lsp:symbols('let $x :='))
```
