# Hello RESTXQ

RESTXQ lets you build web APIs directly in XQuery using annotations. Instead of writing routing logic in `controller.xq` or configuring an OpenAPI spec, you annotate XQuery functions with `%rest:path`, `%rest:GET`, etc., and eXist-db maps HTTP requests to those functions automatically.

> **Note:** This book is a reference guide, not an executable notebook. The code examples are RESTXQ *module declarations* — they show what you'd write in a `.xqm` file and deploy to the database. They can't be run directly in the sandbox editor because RESTXQ modules need to be stored in the database and invoked via HTTP requests, not evaluated as standalone expressions. Read the code, then try it in your own app!

## Your first endpoint

A RESTXQ function needs two things: a path annotation and at least one HTTP method annotation (or the method is inferred as GET by default):

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";

declare
    %rest:path("/api/hello")
    %rest:GET
function api:hello() {
    <message>Hello from RESTXQ!</message>
};
```

Save this as a `.xqm` file in a collection with the RESTXQ trigger enabled, and it's immediately available at `/exist/restxq/api/hello`.

## How it works

RESTXQ is a spec from the EXQuery project that maps HTTP concepts to XQuery annotations:

| Annotation | Purpose |
|---|---|
| `%rest:path("/route")` | Maps the function to a URL path |
| `%rest:GET` | Responds to HTTP GET requests |
| `%rest:POST` | Responds to HTTP POST requests |
| `%rest:PUT` | Responds to HTTP PUT requests |
| `%rest:DELETE` | Responds to HTTP DELETE requests |

The annotations are part of the function declaration — no separate configuration files needed.

## Returning different types

RESTXQ functions can return any XQuery value. The serializer handles the rest:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Return XML — the default :)
declare
    %rest:path("/api/time")
    %rest:GET
function api:time() {
    <current-time>{current-dateTime()}</current-time>
};

(: Return plain text :)
declare
    %rest:path("/api/greeting")
    %rest:GET
    %output:method("text")
function api:greeting() {
    "Hello, World! The time is " || format-dateTime(current-dateTime(), "[h]:[m01] [P]")
};

(: Return JSON :)
declare
    %rest:path("/api/status")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function api:status() {
    map {
        "status": "ok",
        "version": system:get-version(),
        "timestamp": string(current-dateTime())
    }
};
```

## RESTXQ vs. controller.xq + Roaster

eXist-db has traditionally used `controller.xq` for URL routing and, more recently, Roaster for OpenAPI-based routing. RESTXQ is a third option with distinct advantages:

| Feature | controller.xq | Roaster | RESTXQ |
|---|---|---|---|
| Routing defined in | XQuery dispatch file | OpenAPI JSON | Function annotations |
| Spec-based | No | Yes (OpenAPI) | Yes (EXQuery) |
| Portable to BaseX | No | No | Yes |
| Content negotiation | Manual | Manual | Built-in |
| Error handling | Manual | Manual | Built-in |
| Auth integration | Manual | Custom | Annotation-based |

RESTXQ is especially attractive when portability across XQuery engines matters, or when you want the routing to live right next to the function it routes to.

## What you'll learn

This book walks through RESTXQ from basics to a complete API:

1. **Path routing** — static paths, path variables, regex patterns
2. **HTTP methods** — GET, POST, PUT, DELETE, and request body binding
3. **Parameters** — query strings, form fields, headers, cookies
4. **Serialization** — controlling output format and media types
5. **Content negotiation** — `consumes` and `produces` annotations
6. **Error handling** — `%rest:error` annotations for structured error responses
7. **A complete API** — putting it all together with a real CRUD example
