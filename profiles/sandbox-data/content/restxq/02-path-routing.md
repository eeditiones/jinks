# Path Routing and Variables

The `%rest:path` annotation is the core of RESTXQ routing. It maps URL paths to functions and can capture parts of the path as variables.

## Static paths

The simplest form matches an exact path:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/version")
    %rest:GET
    %output:method("text")
function api:version() {
    "eXist-db " || system:get-version()
};
```

A request to `/exist/restxq/api/version` invokes this function. A request to any other path returns 404.

## Path variables

Curly braces in the path template capture segments as function parameters:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/greet/{$name}")
    %rest:GET
    %output:method("text")
function api:greet($name) {
    "Hello, " || $name || "!"
};
```

A request to `/exist/restxq/api/greet/Alice` returns `Hello, Alice!`. The `{$name}` template variable binds to the `$name` function parameter.

## Multiple variables

You can capture multiple path segments:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/math/{$a}/{$b}")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function api:math($a as xs:integer, $b as xs:integer) {
    map {
        "a": $a,
        "b": $b,
        "sum": $a + $b,
        "product": $a * $b
    }
};
```

A request to `/exist/restxq/api/math/7/6` returns `{"a":7,"b":6,"sum":13,"product":42}`.

Notice the type declarations: `$a as xs:integer` tells RESTXQ to cast the path segment from a string to an integer. If the cast fails (e.g., `/api/math/seven/6`), the server returns a 500 error.

## Typed variables

Path variables are strings by default, but you can declare types to get automatic casting and validation:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Only matches when {$id} is a valid integer :)
declare
    %rest:path("/api/item/{$id}")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function api:item($id as xs:integer) {
    map {
        "id": $id,
        "name": "Item " || $id,
        "found": true()
    }
};
```

Supported types include `xs:string` (default), `xs:integer`, `xs:decimal`, `xs:double`, `xs:boolean`, `xs:date`, and other atomic types. Node types like `node()` or `element()` are not allowed in path variables.

## Path precedence

When multiple functions could match a request, RESTXQ picks the most specific match:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Specific path wins over variable :)
declare
    %rest:path("/api/users/me")
    %rest:GET
    %output:method("text")
function api:current-user() {
    "You are the current user"
};

(: Variable path is the fallback :)
declare
    %rest:path("/api/users/{$id}")
    %rest:GET
    %output:method("text")
function api:user-by-id($id) {
    "User ID: " || $id
};
```

A request to `/api/users/me` returns "You are the current user". A request to `/api/users/42` returns "User ID: 42". The literal path `/api/users/me` takes precedence over the template `/api/users/{$id}`.

## Regex path variables (BaseX extension)

For advanced routing, path variables can include regex patterns:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Only matches digits :)
declare
    %rest:path("/api/order/{$id=[0-9]+}")
    %rest:GET
    %output:method("text")
function api:order($id) {
    "Order #" || $id
};

(: Matches any remaining path :)
declare
    %rest:path("/api/files/{$path=.+}")
    %rest:GET
    %output:method("text")
function api:file($path) {
    "Requested file: " || $path
};
```

The regex `[0-9]+` ensures `/api/order/abc` returns 404 instead of matching. The regex `.+` captures multiple path segments, so `/api/files/docs/report.pdf` sets `$path` to `docs/report.pdf`.

> **Note:** Regex path variables are a BaseX extension to the RESTXQ spec. They are supported in eXist-db's native RESTXQ implementation but may not be portable to other XQuery engines.
