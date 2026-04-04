# HTTP Methods and Request Bodies

RESTXQ supports all standard HTTP methods and lets you bind request bodies directly to function parameters.

## GET and DELETE

GET and DELETE are the simplest — they don't have request bodies:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/items")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function api:list-items() {
    array {
        map { "id": 1, "name": "Widget" },
        map { "id": 2, "name": "Gadget" },
        map { "id": 3, "name": "Thingamajig" }
    }
};

declare
    %rest:path("/api/items/{$id}")
    %rest:DELETE
    %output:method("text")
function api:delete-item($id as xs:integer) {
    "Deleted item " || $id
};
```

## POST with body binding

POST and PUT can bind the request body to a function parameter using `%rest:POST('{$body}')`:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: Accept XML body :)
declare
    %rest:path("/api/items")
    %rest:POST("{$body}")
    %rest:consumes("application/xml")
    %output:method("text")
function api:create-item-xml($body as document-node()) {
    "Created: " || $body/item/name/string()
};

(: Accept plain text body :)
declare
    %rest:path("/api/echo")
    %rest:POST("{$body}")
    %rest:consumes("text/plain")
    %output:method("text")
function api:echo($body) {
    "You said: " || $body
};
```

The `{$body}` template in `%rest:POST` tells RESTXQ which function parameter receives the request body. The body is automatically parsed based on the Content-Type:

| Content-Type | XQuery type |
|---|---|
| `application/xml`, `text/xml` | `document-node()` |
| `text/plain` | `xs:string` |
| `application/json` | parsed to XML map representation |
| `application/octet-stream` | `xs:base64Binary` |

## PUT for updates

PUT works exactly like POST — just use `%rest:PUT` instead:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/items/{$id}")
    %rest:PUT("{$body}")
    %rest:consumes("application/xml")
    %output:method("text")
function api:update-item($id as xs:integer, $body as document-node()) {
    "Updated item " || $id || ": " || $body/item/name/string()
};
```

Notice that the function has both a path variable (`$id`) and a body variable (`$body`). RESTXQ binds each from the appropriate source.

## HEAD and OPTIONS

HEAD requests are auto-generated from GET endpoints — the server runs the GET handler but strips the response body. You can also declare explicit HEAD handlers:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";

(: Explicit HEAD handler — must return rest:response :)
declare
    %rest:path("/api/ping")
    %rest:HEAD
function api:ping-head() {
    <rest:response>
        <http:response xmlns:http="http://expath.org/ns/http-client"
            status="200" message="OK">
            <http:header name="X-Ping" value="pong"/>
        </http:response>
    </rest:response>
};

(: GET handler — HEAD is auto-generated from this :)
declare
    %rest:path("/api/ping")
    %rest:GET
function api:ping() {
    <pong/>
};
```

OPTIONS works similarly — auto-generated from existing endpoints, or you can declare explicit handlers.

## Custom methods (BaseX extension)

The `%rest:method` annotation lets you handle non-standard HTTP methods:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/items/{$id}")
    %rest:method("PATCH", "{$body}")
    %rest:consumes("application/json")
    %output:method("json")
    %output:media-type("application/json")
function api:patch-item($id as xs:integer, $body) {
    map {
        "id": $id,
        "patched": true(),
        "body": string($body)
    }
};
```

> **Note:** `%rest:method` is a BaseX extension. For portable RESTXQ code, stick to `%rest:GET`, `%rest:POST`, `%rest:PUT`, and `%rest:DELETE`.
