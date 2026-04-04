# Authentication

The HTTP Client supports HTTP Basic authentication natively and can integrate with other authentication schemes via custom headers.

## Basic Authentication

Use the `username`, `password`, and `auth-method` attributes. Set `send-authorization="true"` to send credentials on the first request (preemptive auth):

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET"
                  href="https://httpbin.org/basic-auth/admin/secret123"
                  username="admin"
                  password="secret123"
                  auth-method="basic"
                  send-authorization="true"/>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <authenticated>{$json?authenticated}</authenticated>
        <user>{$json?user}</user>
    </result>
```

## Bearer Token Authentication

Most modern APIs use Bearer tokens. Send them via a custom `Authorization` header:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $token := "my-demo-token-12345"

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/get">
        <http:header name="Authorization" value="Bearer {$token}"/>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    <result>
        <status>{string($response[1]/@status)}</status>
        <sent-auth>{$json?headers?Authorization}</sent-auth>
    </result>
```

## API Key Authentication

Some APIs pass the key as a header:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/get">
        <http:header name="X-API-Key" value="my-api-key-12345"/>
        <http:header name="Accept" value="application/json"/>
    </http:request>
)
let $json := parse-json(util:binary-to-string($response[2]))
return
    $json?headers?X-Api-Key
```

## Handling 401 Unauthorized

When credentials are wrong or missing, the server returns 401:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET"
                  href="https://httpbin.org/basic-auth/admin/secret123"
                  username="wrong"
                  password="wrong"
                  auth-method="basic"
                  send-authorization="true"/>
)
return
    if ($response[1]/@status = "401") then
        <auth-required>
            <message>Authentication failed</message>
            <www-authenticate>{
                $response[1]/http:header[lower-case(@name) = "www-authenticate"]/@value/string()
            }</www-authenticate>
        </auth-required>
    else
        <authenticated/>
```
