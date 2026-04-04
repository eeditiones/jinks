# Compile Check

The `/ws/eval` endpoint supports a `compile` action that validates XQuery syntax without executing the query. This is ideal for real-time syntax checking in editors — the foundation for "squiggly red underlines."

## How Compile Check Works

The client sends `{"action": "compile", "id": "c-1", "query": "..."}`. The server parses and compiles the query but does NOT evaluate it. The response is either:

**Success:**
```json
{"type": "compile", "id": "c-1", "success": true}
```

**Failure:**
```json
{
    "type": "compile", "id": "c-1", "success": false,
    "diagnostics": [{
        "line": 1, "column": 12,
        "severity": "error",
        "code": "XPST0003",
        "message": "unexpected token: retrun"
    }]
}
```

## Valid Query

This query compiles successfully — no execution, just validation:

```xquery
for $i in 1 to 10
let $x := $i * 2
where $x gt 5
return $x
```

## Syntax Errors

A typo in a keyword is caught during parsing (XPST0003):

```xquery
(: "retrun" is not a valid keyword :)
let $x := 1
retrun $x
```

## Type Errors (Static)

Some type errors are caught at compile time:

```xquery
(: Comparing incompatible types :)
declare function local:add($a as xs:integer, $b as xs:string) as xs:integer {
    $a + $b
};
local:add(1, "hello")
```

## Unknown Functions

References to undefined functions are caught during compilation:

```xquery
(: No such function in scope :)
local:nonexistent-function(42)
```

## Namespace Errors

Invalid namespace prefixes are detected:

```xquery
(: Undeclared namespace prefix :)
foo:bar("test")
```

## Module Import Validation

The compile action also validates module imports. This is useful for checking that all dependencies are available:

```xquery
import module namespace math = "http://www.w3.org/2005/xpath-functions/math";

math:pi()
```

## Use Cases

### Editor Integration

An editor can compile-check on every keystroke (debounced) to provide instant feedback. Since compilation is much faster than evaluation, the latency is typically under 20ms.

### CI/CD Validation

Compile-check all XQuery files in a project without executing them — useful for catching syntax errors before deployment:

```xquery
(: A build script could compile-check every .xq file :)
for $uri in xmldb:get-child-resources("/db/apps/myapp/modules")
where ends-with($uri, ".xq") or ends-with($uri, ".xqm")
return
    <module uri="{$uri}">{
        try {
            util:compile-query(
                util:binary-to-string(util:binary-doc(concat("/db/apps/myapp/modules/", $uri))),
                "xmldb:exist:///db/apps/myapp/modules/"
            )
        } catch * {
            <error>{$err:description}</error>
        }
    }</module>
```

### REPL Autocomplete

Before showing completions, verify the partial expression compiles. This prevents offering completions for fundamentally broken syntax.
