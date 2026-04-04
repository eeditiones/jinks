# Basic Requests

The EXPath HTTP Client Module provides a single function — `http:send-request` — for making HTTP requests from XQuery. It supports all common HTTP methods and returns a sequence where the first item is a response descriptor element and the remaining items are response body content.

> **Compatibility note:** eXist-db's current built-in HTTP Client returns JSON and text responses as `xs:base64Binary`. These examples use `util:binary-to-string()` to convert the body to a string before parsing, which works with both the current and the new native HTTP Client module (which returns text as `xs:string` directly).

## Simple GET Request

The simplest form takes an `<http:request>` element with a method and URL:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

http:send-request(
    <http:request method="GET" href="https://httpbin.org/get"/>
)
```

The result is a sequence of two items: an `<http:response>` element (with status, headers, and a body descriptor) followed by the response body content.

## Examining the Response Element

The first item in the response is always an `<http:response>` element with `@status` and `@message` attributes:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/get"/>
)
let $meta := $response[1]
return
    <result>
        <status>{string($meta/@status)}</status>
        <message>{string($meta/@message)}</message>
        <header-count>{count($meta/http:header)}</header-count>
    </result>
```

## Reading Response Headers

Response headers appear as `<http:header>` child elements with `@name` and `@value` attributes:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/headers"/>
)
return
    $response[1]/http:header
```

To find a specific header (case-insensitive):

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/get"/>
)
return
    $response[1]/http:header[lower-case(@name) = "content-type"]/@value/string()
```

## Sending Custom Headers

Add `<http:header>` children to the request element:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/headers">
        <http:header name="Accept" value="application/json"/>
        <http:header name="X-Custom-Header" value="hello-from-xquery"/>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?headers?X-Custom-Header
```

## The Two-Argument Form

The URL can be passed as a second argument, which overrides any `@href` on the request element. This is useful when the URL is computed dynamically:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $base := "https://httpbin.org"
let $endpoint := $base || "/get"
let $response := http:send-request(
    <http:request method="GET">
        <http:header name="Accept" value="application/json"/>
    </http:request>,
    $endpoint
)
return string($response[1]/@status)
```

## HEAD Requests

A HEAD request returns only the response element — no body:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="HEAD" href="https://httpbin.org/get"/>
)
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <items-returned>{count($response)}</items-returned>
        <content-type>{
            $response[1]/http:header[lower-case(@name) = "content-type"]/@value/string()
        }</content-type>
    </result>
```

## Handling Errors

Non-2xx status codes are returned normally — they don't raise errors. You can check `@status` to handle them:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/status/404"/>
)
let $status := xs:integer($response[1]/@status)
return
    if ($status ge 200 and $status lt 300) then
        <success/>
    else if ($status ge 400 and $status lt 500) then
        <client-error status="{$status}">{$response[1]/@message/string()}</client-error>
    else
        <server-error status="{$status}">{$response[1]/@message/string()}</server-error>
```

Connection failures, invalid URIs, and timeouts raise XQuery errors (HC001, HC005, HC006) that can be caught with `try/catch`.
