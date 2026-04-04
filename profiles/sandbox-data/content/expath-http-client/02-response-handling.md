# Response Handling

The HTTP Client automatically classifies response bodies by Content-Type. XML responses are parsed into document nodes that you can query with XPath. Text and JSON responses need `util:binary-to-string()` to convert from `xs:base64Binary` to a string for processing.

## JSON Responses

JSON responses from httpbin need to be converted from binary to string before parsing:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/json"/>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    <slideshow title="{$json?slideshow?title}">
        <slide-count>{array:size($json?slideshow?slides)}</slide-count>
    </slideshow>
```

## XML Responses

XML responses (`application/xml`, `text/xml`, or any `*+xml` subtype) are automatically parsed into a document node that you can query with XPath:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/xml"/>
)
let $doc := $response[2]
return
    <summary>
        <type>{$doc instance of document-node()}</type>
        <slides>{count($doc//slide)}</slides>
    </summary>
```

## Plain Text Responses

Text responses (`text/plain`, `text/css`, `text/csv`) are returned as `xs:string`:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/robots.txt"/>
)
let $text := $response[2]
return
    <result>
        <is-string>{$text instance of xs:string}</is-string>
        <length>{string-length($text)}</length>
        <preview>{substring($text, 1, 100)}</preview>
    </result>
```

## HTML Responses

HTML responses are parsed as document nodes, just like XML:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/html"/>
)
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <is-document>{$response[2] instance of document-node()}</is-document>
    </result>
```

## Content-Type Classification Summary

| Content-Type | Return Type | Access Pattern |
|---|---|---|
| `text/xml`, `application/xml`, `*+xml` | `document-node()` | XPath directly: `$response[2]//element` |
| `text/html` | `document-node()` | XPath directly: `$response[2]//p` |
| `text/*` (plain, css, csv, etc.) | `xs:string` | Direct: `$response[2]` |
| `application/json`, `*+json` | `xs:base64Binary` | Convert: `util:binary-to-string($response[2])` |
| Everything else | `xs:base64Binary` | Binary data |

## The status-only Attribute

When you only need the status and headers (not the body), use `status-only="true"`:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/get"
                  status-only="true"/>
)
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <items>{count($response)}</items>
        <has-body>{count($response) > 1}</has-body>
    </result>
```

## Redirects

By default, redirects are followed automatically. Control this with `follow-redirect`:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

(: Don't follow — see the redirect itself :)
let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/redirect/1"
                  follow-redirect="false"/>
)
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <location>{
            $response[1]/http:header[lower-case(@name) = "location"]/@value/string()
        }</location>
    </result>
```

## Timeouts

Set a timeout in seconds to avoid hanging on slow servers:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

try {
    http:send-request(
        <http:request method="GET" href="https://httpbin.org/delay/10"
                      timeout="2"/>
    )
} catch * {
    <timeout>
        <code>{$err:code}</code>
        <message>{$err:description}</message>
    </timeout>
}
```
