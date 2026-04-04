# Diagnostics

The `lsp:diagnostics()` function compiles an XQuery expression and returns any errors it finds. This is the foundation of real-time error checking in editors — red squiggles, error markers, and problem panels all start here.

## Valid code returns an empty array

When the expression compiles successfully, you get back an empty array:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'let $x := 1 return $x + 1'
return array:size(lsp:diagnostics($code))
```

## Syntax errors are caught

A typo like `retrun` instead of `return` produces a diagnostic:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

lsp:diagnostics('let $x := 1 retrun $x')
```

Each diagnostic is a map with keys that follow the Language Server Protocol: `line`, `column` (both 0-based), `severity` (1 = error), `code` (the W3C error code), and `message`.

## Static analysis errors

The compiler catches more than just syntax. Undeclared variables produce `XPST0008`:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $diag := lsp:diagnostics('$undeclared')
return map {
    "code": $diag(1)?code,
    "message": $diag(1)?message
}
```

## Multi-line error positions

Line and column numbers are 0-based, matching the LSP convention. Here the error is on line 2 (the third line):

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := 'xquery version "3.1";

let $x := 1 retrun $x'

let $diag := lsp:diagnostics($code)
return map {
    "line": $diag(1)?line,
    "column": $diag(1)?column,
    "message": $diag(1)?message
}
```

## Resolving database imports

The optional second parameter sets the module load path, so `import module` statements resolve correctly:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

(: This code imports a module from /db — use the load path so the compiler can find it :)
let $code := 'import module namespace util = "http://exist-db.org/xquery/util";
util:system-property("product-version")'

return array:size(lsp:diagnostics($code, "xmldb:exist:///db"))
```
