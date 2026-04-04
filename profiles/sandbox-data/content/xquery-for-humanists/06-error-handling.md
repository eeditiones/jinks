# Handling Errors

XQuery distinguishes between *static errors* (caught at compile time) and *dynamic errors* (raised at runtime). Understanding both helps you write robust queries.

## Static Errors

Static errors are syntax mistakes that the XQuery processor catches before execution:

```xquery
(: This will produce a static error — missing $ on variable name :)
(: Uncomment to see the error: :)
(: let x = 1 return x :)

(: The correct syntax is: :)
let $x := 1
return $x
```

## Raising Errors

Use `fn:error()` to raise a dynamic error intentionally:

```xquery
declare function local:fetch-data($URI as xs:string) as document-node() {
    fn:error(xs:QName("err:FODC0002"), "Error retrieving resource.")
};

local:fetch-data("https://example.org/data")
```

## Try/Catch

Catch errors with `try`/`catch` to handle them gracefully:

```xquery
declare function local:fetch-data($URI as xs:string) as document-node() {
    fn:error(xs:QName("err:FODC0002"), "Error retrieving resource.")
};

try {
    local:fetch-data("https://example.org/data")
}
catch * {
    "I caught this error: " || $err:code ||
    " with this description: " || $err:description
}
```

The `catch *` wildcard catches any error. Inside the catch block, `$err:code` and `$err:description` provide details about what went wrong.

## Catching Specific Errors

You can catch specific error codes and provide targeted handling:

```xquery
declare function local:fetch-data($URI as xs:string) as document-node() {
    fn:error(xs:QName("err:FODC0002"), "Error retrieving resource.")
};

try {
    local:fetch-data("https://example.org/data")
}
catch err:FODC0002 { "The web service failed." }
catch * { "Something else happened!" }
```

The first matching `catch` clause is executed. Put specific catches before the wildcard.

## Documenting Your Code

XQuery supports xqDoc comments (similar to Javadoc) for documenting functions:

```xquery
(:~
 : This function expresses a friendly greeting.
 :
 : @param $name The name of the person to greet
 : @return An English-language salutation
 :)
declare function local:say-hello($name as xs:string?) as xs:string {
    "Hello, " || $name || "!"
};

local:say-hello("Digital Humanist")
```

The `(:~ ... :)` syntax marks a documentation comment. Tags like `@param`, `@return`, and `@author` are recognized by xqDoc tools.
