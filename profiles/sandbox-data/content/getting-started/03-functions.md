# Functions and Recursion

XQuery lets you define your own functions using `declare function`. Functions in the `local:` namespace are available within the current query without needing a module declaration.

## A Simple Function

Define a greeting function that takes a name and language:

```xquery
declare function local:greet($name as xs:string, $lang as xs:string?) as xs:string {
    if ($lang = "de") then
        "Hallo " || $name
    else if ($lang = "es") then
        "Hola " || $name
    else
        "Hello " || $name
};

local:greet("Susi", "de"),
local:greet("Susi", "es"),
local:greet("Susi", "en"),
local:greet("Susi", ())
```

The `?` after `xs:string` in the type declaration for `$lang` means the parameter is optional — it can be an empty sequence `()`. When no language is provided, the function defaults to English.

## Recursion

XQuery functions can call themselves recursively. Here's the classic factorial:

```xquery
declare function local:fact($n as xs:integer) {
    if ($n eq 1) then
        $n
    else
        $n * local:fact($n - 1)
};

local:fact(6)
```

The function multiplies `$n` by the factorial of `$n - 1`, with the base case returning 1 when `$n` equals 1. The result is 720 (6 × 5 × 4 × 3 × 2 × 1).
