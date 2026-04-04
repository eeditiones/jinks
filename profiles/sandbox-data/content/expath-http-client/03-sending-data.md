# Sending Data

HTTP methods like POST, PUT, and PATCH send data in the request body. The HTTP Client supports sending text, JSON, XML, and form data.

## POST with a Text Body

Send plain text as the body of a POST request:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="POST" href="https://httpbin.org/post">
        <http:body media-type="text/plain">Hello from XQuery!</http:body>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?data
```

## POST with XML Body

XML content inside `<http:body>` is serialized automatically:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="POST" href="https://httpbin.org/post">
        <http:body media-type="application/xml">
            <order>
                <item id="1">Widget</item>
                <item id="2">Gadget</item>
                <quantity>5</quantity>
            </order>
        </http:body>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?data
```

## POST with Form Data

Send URL-encoded form data:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="POST" href="https://httpbin.org/post">
        <http:body media-type="application/x-www-form-urlencoded">username=admin&amp;action=login&amp;remember=true</http:body>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    <form-data>
        <username>{$json?form?username}</username>
        <action>{$json?form?action}</action>
    </form-data>
```

## PUT Request

PUT is typically used to create or replace a resource:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="PUT" href="https://httpbin.org/put">
        <http:body media-type="text/plain">updated content</http:body>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <echoed-data>{$json?data}</echoed-data>
    </result>
```

## PATCH Request

PATCH sends a partial update:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="PATCH" href="https://httpbin.org/patch">
        <http:body media-type="text/plain">partial update</http:body>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?data
```

## DELETE Request

DELETE requests typically have no body:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="DELETE" href="https://httpbin.org/delete"/>
)
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <message>{string($response[1]/@message)}</message>
    </result>
```

## The Three-Argument Form

The third argument provides the body externally, which is useful when the body content is computed separately:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $data := serialize(
    <document>
        <title>External Body</title>
        <content>Passed as third argument</content>
    </document>
)
let $response := http:send-request(
    <http:request method="POST">
        <http:body media-type="application/xml"/>
    </http:request>,
    "https://httpbin.org/post",
    $data
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?data
```

## Building Requests Dynamically

Since the request is just an XML element, you can build it programmatically:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $query := "XQuery database"
let $url := "https://httpbin.org/get?q=" || encode-for-uri($query)

let $request :=
    <http:request method="GET" href="{$url}" timeout="10">
        <http:header name="Accept" value="application/json"/>
        <http:header name="User-Agent" value="eXist-db/7.0"/>
    </http:request>

let $response := http:send-request($request)
return
    if ($response[1]/@status = "200") then
        let $json := parse-json(util:binary-to-string($response[2]))
        return
            <result>
                <url>{$json?url}</url>
                <query>{$json?args?q}</query>
            </result>
    else
        <error status="{$response[1]/@status}"/>
```
