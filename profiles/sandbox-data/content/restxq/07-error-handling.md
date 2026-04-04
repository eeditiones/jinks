# Error Handling

RESTXQ's `%rest:error` annotation lets you catch XQuery errors and return structured HTTP error responses instead of raw stack traces.

## Catching all errors

The simplest error handler catches everything:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: A function that deliberately fails :)
declare
    %rest:path("/api/boom")
    %rest:GET
function api:boom() {
    error(xs:QName("api:KABOOM"), "Something went wrong!")
};

(: Catch-all error handler :)
declare
    %rest:error("*")
    %output:method("json")
    %output:media-type("application/json")
function api:handle-error() {
    map {
        "error": true(),
        "message": "An internal error occurred"
    }
};
```

When `/api/boom` is called, the error is caught by `api:handle-error`, and the client receives a JSON error response instead of a 500 page with a Java stack trace.

## Catching specific errors

You can target specific error codes. Precedence follows specificity:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = "http://expath.org/ns/http-client";

declare variable $api:NOT-FOUND := xs:QName("api:NOT_FOUND");
declare variable $api:FORBIDDEN := xs:QName("api:FORBIDDEN");

(: Endpoint that raises a "not found" error :)
declare
    %rest:path("/api/thing/{$id}")
    %rest:GET
function api:get-thing($id as xs:integer) {
    if ($id > 100) then
        error($api:NOT-FOUND, "Thing " || $id || " does not exist")
    else if ($id < 0) then
        error($api:FORBIDDEN, "Negative IDs are not allowed")
    else
        <thing id="{$id}">Found it!</thing>
};

(: Handle NOT_FOUND errors → 404 :)
declare
    %rest:error("api:NOT_FOUND")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function api:handle-not-found($desc) {
    <rest:response>
        <http:response status="404"/>
    </rest:response>,
    map { "error": "not_found", "message": string($desc) }
};

(: Handle FORBIDDEN errors → 403 :)
declare
    %rest:error("api:FORBIDDEN")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function api:handle-forbidden($desc) {
    <rest:response>
        <http:response status="403"/>
    </rest:response>,
    map { "error": "forbidden", "message": string($desc) }
};

(: Catch everything else → 500 :)
declare
    %rest:error("*")
    %rest:error-param("description", "{$desc}")
    %output:method("json")
    %output:media-type("application/json")
function api:handle-other($desc) {
    <rest:response>
        <http:response status="500"/>
    </rest:response>,
    map { "error": "internal", "message": string($desc) }
};
```

## Error parameters

The `%rest:error-param` annotation binds error details to function parameters:

| Parameter name | Value |
|---|---|
| `code` | The QName of the error (e.g., `api:NOT_FOUND`) |
| `description` | The error description string |
| `value` | The error value (the third argument to `error()`) |
| `module` | The module URI where the error occurred |
| `line-number` | The line number where the error occurred |

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Detailed error handler with all parameters :)
declare
    %rest:error("*")
    %rest:error-param("code", "{$code}")
    %rest:error-param("description", "{$desc}")
    %rest:error-param("module", "{$module}")
    %rest:error-param("line-number", "{$line}")
    %output:method("json")
    %output:media-type("application/json")
function api:detailed-error($code, $desc, $module, $line) {
    map {
        "error": string($code),
        "message": string($desc),
        "source": map {
            "module": string($module),
            "line": $line
        }
    }
};
```

## Wildcard patterns

Error annotations support wildcard patterns for matching families of errors:

| Pattern | Matches |
|---|---|
| `*` | Any error |
| `err:*` | Any error in the `err` namespace |
| `*:FORG0001` | FORG0001 in any namespace |
| `err:FORG0001` | Only err:FORG0001 |
| `Q{http://...}FORG0001` | URI-qualified match |

Precedence: exact QName > prefix:* > *:local > *

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Catch any type error :)
declare
    %rest:error("err:*")
    %output:method("text")
function api:type-errors() {
    "A type or evaluation error occurred"
};

(: Catch specifically FORG0001 :)
declare
    %rest:error("err:FORG0001")
    %output:method("text")
function api:forg0001() {
    "Invalid value for cast/constructor"
};

(: Fallback :)
declare
    %rest:error("*")
    %output:method("text")
function api:any-error() {
    "Something went wrong"
};
```

If `err:FORG0001` is raised, the specific handler wins. If `err:XPDY0002` is raised, the `err:*` handler catches it. If `api:CUSTOM` is raised, the `*` fallback handles it.
