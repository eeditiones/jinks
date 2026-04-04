# Applications

The LSP module functions are building blocks. Here are practical applications that combine them.

## XQuery linter

Check a collection of XQuery files for compilation errors:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

(: Lint a few inline "files" to demonstrate the pattern :)
let $files := map {
    "app.xq": 'declare function local:main() { "ok" }; local:main()',
    "broken.xq": 'let $x := 1 retrun $x',
    "lib.xqm": 'module namespace lib = "http://example.com/lib";
declare function lib:hello() as xs:string { "hello" };'
}

for $name in map:keys($files)
let $code := $files($name)
let $diags := lsp:diagnostics($code)
order by $name
return map {
    "file": $name,
    "status": if (array:size($diags) = 0) then "ok" else "error",
    "errors": array:for-each($diags, function($d) {
        $d?code || " at line " || $d?line || ": " || $d?message
    })
}
```

## Module API documentation generator

Extract a function catalog from XQuery code:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare function local:connect($host as xs:string, $port as xs:integer) as map(*) {
    map { "host": $host, "port": $port, "status": "connected" }
};
declare function local:disconnect($conn as map(*)) as xs:boolean {
    true()
};
declare function local:query($conn as map(*), $sql as xs:string) as item()* {
    ()
};
local:connect("localhost", 5432)'

let $symbols := lsp:symbols($code)
let $functions := array:filter($symbols, function($s) { $s?kind = 12 })

return
    <api>
    {
        array:for-each($functions, function($fn) {
            <function name="{$fn?name}" line="{$fn?line}">
                <signature>{$fn?detail}</signature>
            </function>
        })
    }
    </api>
```

## Dead code detector

Find functions and variables that are declared but never referenced:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare variable $local:API_KEY := "secret-123";
declare variable $local:UNUSED_CONFIG := map {};
declare function local:fetch($url as xs:string) as xs:string { $url };
declare function local:parse($data as xs:string) as map(*) { map { "data": $data } };
declare function local:legacy-handler() { () };
local:fetch("https://api.example.com") => local:parse()'

let $symbols := lsp:symbols($code)

return
    <dead-code-report>
    {
        array:for-each($symbols, function($sym) {
            let $refs := lsp:references($code, $sym?line, $sym?column)
            (: 1 reference = only the declaration itself :)
            return if (array:size($refs) <= 1)
            then <unused name="{$sym?name}" line="{$sym?line}" kind="{
                if ($sym?kind = 12) then 'function' else 'variable'
            }"/>
            else ()
        })
    }
    </dead-code-report>
```

## Complexity metrics

Count declarations and cross-references as a rough complexity measure:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare variable $local:config := map { "max-retries": 3 };

declare function local:validate($input as xs:string) as xs:boolean {
    string-length($input) > 0 and string-length($input) < 1000
};

declare function local:transform($data as xs:string) as xs:string {
    if (local:validate($data))
    then upper-case($data)
    else error(xs:QName("local:INVALID"), "Invalid input")
};

declare function local:process($items as xs:string*) as xs:string* {
    for $item in $items
    where local:validate($item)
    return local:transform($item)
};

local:process(("hello", "", "world"))'

let $symbols := lsp:symbols($code)
let $diags := lsp:diagnostics($code)
let $completions := lsp:completions($code)
let $user-fns := array:filter($symbols, function($s) { $s?kind = 12 })

return map {
    "functions": array:size($user-fns),
    "variables": array:size(array:filter($symbols, function($s) { $s?kind = 13 })),
    "total-symbols": array:size($symbols),
    "compiles-clean": array:size($diags) = 0,
    "available-completions": array:size($completions),
    "function-names": array:for-each($user-fns, function($f) { $f?name })
}
```

## Interactive function explorer

Build a map of which functions call which:

```xquery
import module namespace lsp = "http://exist-db.org/xquery/lsp";

let $code := '
declare function local:a() { local:b(), local:c() };
declare function local:b() { local:c() };
declare function local:c() { "leaf" };
declare function local:d() { local:a() };
local:d()'

let $symbols := lsp:symbols($code)
let $functions := array:filter($symbols, function($s) { $s?kind = 12 })

return map:merge(
    array:for-each($functions, function($fn) {
        let $refs := lsp:references($code, $fn?line, max((0, $fn?column)))
        (: Callers are references on lines other than the declaration line :)
        let $callers := array:filter($refs, function($r) { $r?line != $fn?line })
        return map:entry($fn?name, map {
            "declared-at": "line " || $fn?line,
            "called-from": array:size($callers) || " locations"
        })
    })?*
)
```
