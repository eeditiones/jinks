# Serialization and Content Types

RESTXQ uses XQuery serialization annotations to control how function return values are converted to HTTP responses.

## Output method annotations

The `%output:method` annotation controls the serialization format:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: XML output — the default :)
declare
    %rest:path("/api/data/xml")
    %rest:GET
    %output:method("xml")
    %output:indent("yes")
function api:data-xml() {
    <catalog>
        <book id="1">
            <title>XQuery: Search Across a Variety of XML Data</title>
            <author>Priscilla Walmsley</author>
        </book>
        <book id="2">
            <title>XQuery for Humanists</title>
            <author>Clifford Anderson</author>
        </book>
    </catalog>
};

(: JSON output :)
declare
    %rest:path("/api/data/json")
    %rest:GET
    %output:method("json")
    %output:media-type("application/json")
function api:data-json() {
    map {
        "catalog": array {
            map { "id": 1, "title": "XQuery: Search Across a Variety of XML Data", "author": "Priscilla Walmsley" },
            map { "id": 2, "title": "XQuery for Humanists", "author": "Clifford Anderson" }
        }
    }
};

(: Plain text output :)
declare
    %rest:path("/api/data/text")
    %rest:GET
    %output:method("text")
    %output:media-type("text/plain")
function api:data-text() {
    string-join((
        "Catalog:",
        "  1. XQuery: Search Across a Variety of XML Data (Walmsley)",
        "  2. XQuery for Humanists (Anderson)"
    ), "&#10;")
};

(: HTML output :)
declare
    %rest:path("/api/data/html")
    %rest:GET
    %output:method("html")
    %output:media-type("text/html")
function api:data-html() {
    <html>
        <body>
            <h1>Catalog</h1>
            <ul>
                <li>XQuery: Search Across a Variety of XML Data</li>
                <li>XQuery for Humanists</li>
            </ul>
        </body>
    </html>
};
```

## Media type control

The `%output:media-type` annotation sets the `Content-Type` response header:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: SVG with correct media type :)
declare
    %rest:path("/api/badge")
    %rest:GET
    %output:method("xml")
    %output:media-type("image/svg+xml")
function api:badge() {
    <svg xmlns="http://www.w3.org/2000/svg" width="120" height="20">
        <rect width="120" height="20" rx="3" fill="#555"/>
        <rect x="60" width="60" height="20" rx="3" fill="#4c1"/>
        <text x="30" y="14" fill="#fff" font-size="11" text-anchor="middle">restxq</text>
        <text x="90" y="14" fill="#fff" font-size="11" text-anchor="middle">live</text>
    </svg>
};
```

## Inline serialization with rest:response

For full control over HTTP response headers and status codes, return a `rest:response` element before your content:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = "http://expath.org/ns/http-client";

declare
    %rest:path("/api/download")
    %rest:GET
function api:download() {
    (: The rest:response element controls HTTP headers and serialization :)
    <rest:response>
        <output:serialization-parameters>
            <output:method value="text"/>
        </output:serialization-parameters>
        <http:response status="200" message="OK">
            <http:header name="Content-Disposition"
                         value='attachment; filename="data.txt"'/>
            <http:header name="X-Generated-By" value="RESTXQ"/>
        </http:response>
    </rest:response>,
    (: The actual content follows the rest:response :)
    "id,name,color&#10;1,Widget,blue&#10;2,Gadget,red"
};
```

The `rest:response` element is intercepted by RESTXQ and not included in the output. It can contain:
- `output:serialization-parameters` — overrides `%output:*` annotations
- `http:response` — sets status code, status message, and custom headers

## Serialization precedence

When both annotations and inline `rest:response` are present, the inline parameters win:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace http = "http://expath.org/ns/http-client";

(: Annotation says text, but inline says xml — inline wins :)
declare
    %rest:path("/api/override")
    %rest:GET
    %output:method("text")
function api:override-demo() {
    <rest:response>
        <output:serialization-parameters>
            <output:method value="xml"/>
        </output:serialization-parameters>
        <http:response status="200"/>
    </rest:response>,
    <result>This will be serialized as XML, not text</result>
};
```
