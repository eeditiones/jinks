# Content Negotiation

RESTXQ supports HTTP content negotiation through `%rest:consumes` and `%rest:produces` annotations. These let you route requests based on what content types the client sends and accepts.

## Consumes: filtering by input type

The `%rest:consumes` annotation restricts which Content-Types a function will accept:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Only accepts XML input :)
declare
    %rest:path("/api/items")
    %rest:POST("{$body}")
    %rest:consumes("application/xml")
    %output:method("text")
function api:create-xml($body as document-node()) {
    "Created from XML: " || $body/item/name/string()
};

(: Only accepts JSON input :)
declare
    %rest:path("/api/items")
    %rest:POST("{$body}")
    %rest:consumes("application/json")
    %output:method("text")
function api:create-json($body) {
    "Created from JSON: " || $body
};
```

When a client POSTs `application/xml`, the first function handles it. When a client POSTs `application/json`, the second one handles it. If the Content-Type doesn't match either, the server returns 404.

## Produces: filtering by output type

The `%rest:produces` annotation declares what content types a function can generate. RESTXQ matches this against the client's `Accept` header:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Client sends Accept: application/xml :)
declare
    %rest:path("/api/catalog")
    %rest:GET
    %rest:produces("application/xml")
    %output:method("xml")
    %output:media-type("application/xml")
function api:catalog-xml() {
    <catalog>
        <book><title>XQuery for Humanists</title></book>
    </catalog>
};

(: Client sends Accept: application/json :)
declare
    %rest:path("/api/catalog")
    %rest:GET
    %rest:produces("application/json")
    %output:method("json")
    %output:media-type("application/json")
function api:catalog-json() {
    map {
        "catalog": array {
            map { "title": "XQuery for Humanists" }
        }
    }
};

(: Client sends Accept: text/plain :)
declare
    %rest:path("/api/catalog")
    %rest:GET
    %rest:produces("text/plain")
    %output:method("text")
    %output:media-type("text/plain")
function api:catalog-text() {
    "Catalog: XQuery for Humanists"
};
```

The same path (`/api/catalog`) returns different formats depending on the `Accept` header. This is proper REST content negotiation.

## Wildcards

Use `*/*` to match any content type:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Matches any content type — the fallback :)
declare
    %rest:path("/api/flexible")
    %rest:GET
    %rest:produces("*/*")
    %output:method("text")
function api:flexible() {
    "I'll serve anything"
};
```

## Multiple types

A function can accept or produce multiple types:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Accepts both XML and JSON :)
declare
    %rest:path("/api/ingest")
    %rest:POST("{$body}")
    %rest:consumes("application/xml", "application/json")
    %output:method("text")
function api:ingest($body) {
    "Ingested: " || string($body)
};

(: Serves both XML and JSON (client picks via Accept) :)
declare
    %rest:path("/api/dual")
    %rest:GET
    %rest:produces("application/xml", "application/json")
    %output:method("xml")
function api:dual() {
    <result>Works for both XML and JSON clients</result>
};
```

## Precedence rules

When multiple functions match the same path, RESTXQ uses specificity to pick the winner:

1. **Exact media type** (`application/json`) beats partial match (`application/*`) beats wildcard (`*/*`)
2. **More specific consumes** beats less specific
3. If still tied, the first registered function wins

This means you can have a specific JSON handler and a `*/*` fallback on the same path, and the JSON handler will take precedence for JSON requests.
