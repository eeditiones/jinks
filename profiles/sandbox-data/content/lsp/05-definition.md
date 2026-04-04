# Go to Definition

The `lsp:definition()` function resolves where a symbol is declared — the "Go to Definition" action in editors. Click a function call and jump to its declaration.

## Finding a function's declaration

The call `local:greet()` on line 1 resolves back to its declaration on line 0:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare function local:greet() as xs:string { "hi" };
local:greet()'

return lsp:definition($code, 1, 5)
```

The result is a map with `line`, `column`, `name`, `kind`, and optionally `uri` (for cross-module jumps).

## Finding a variable's declaration

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare variable $local:name := "world";
"Hello, " || $local:name'

return lsp:definition($code, 1, 15)
```

## Built-in functions have no user declaration

`lsp:definition()` returns empty for built-in functions since they don't have a user-declared source location:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $result := lsp:definition("fn:count((1,2,3))", 0, 3)
return if (empty($result))
    then "built-in functions have no user-declared definition"
    else $result
```

## Navigating a complex module

With multiple functions calling each other, you can trace the call chain:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'declare function local:validate($input as xs:string) as xs:boolean {
    string-length($input) > 0
};
declare function local:process($data as xs:string) as xs:string {
    if (local:validate($data)) then upper-case($data) else "invalid"
};
declare function local:run() as xs:string {
    local:process("hello")
};
local:run()'

(: Trace: where is local:process defined? (called on line 4) :)
let $process-def := lsp:definition($code, 4, 19)

(: Where is local:validate defined? (called on line 4) :)
let $validate-def := lsp:definition($code, 4, 19)

return map {
    "process-defined-at": "line " || $process-def?line,
    "process-name": $process-def?name
}
```

## Cross-module definitions

When you use a module load path, definitions can point to other files. The result includes a `uri` field with the source location:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'import module namespace util = "http://exist-db.org/xquery/util";
util:system-property("product-version")'

let $def := lsp:definition($code, 1, 5, "/db")
return if (empty($def))
    then "no definition found (built-in modules don't have source locations)"
    else $def
```
