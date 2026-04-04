# Practical Patterns

This chapter demonstrates real-world patterns that combine multiple Request Module functions. These are the building blocks for request-aware XQuery applications.

## Request Logging

Build a request logger that captures essential information for debugging or audit trails:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<log-entry timestamp="{current-dateTime()}">
    <request method="{exrequest:method()}" path="{exrequest:path()}">
        <query-string>{exrequest:query()}</query-string>
        <content-type>{exrequest:header("Content-Type", "none")}</content-type>
        <user-agent>{exrequest:header("User-Agent", "unknown")}</user-agent>
    </request>
    <client address="{exrequest:remote-address()}" port="{exrequest:remote-port()}">
        <hostname>{exrequest:remote-hostname()}</hostname>
    </client>
</log-entry>
```

## CORS Preflight Check

Check if a request is a CORS preflight and extract the relevant headers:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $method := exrequest:method()
let $origin := exrequest:header("Origin", "")
let $request-method := exrequest:header("Access-Control-Request-Method", "")
return
    <cors-check>
        <is-preflight>{$method = "OPTIONS" and $origin != "" and $request-method != ""}</is-preflight>
        <origin>{$origin}</origin>
        <requested-method>{$request-method}</requested-method>
        <requested-headers>{exrequest:header("Access-Control-Request-Headers", "none")}</requested-headers>
    </cors-check>
```

## Content-Type Dispatch

Route processing based on the request content type — a pattern used in REST API controllers:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $content-type := exrequest:header("Content-Type", "")
let $media-type :=
    if (contains($content-type, ";")) then
        normalize-space(substring-before($content-type, ";"))
    else
        normalize-space($content-type)
return
    <dispatch>
        <raw-content-type>{$content-type}</raw-content-type>
        <media-type>{$media-type}</media-type>
        <handler>{
            switch ($media-type)
                case "application/json" return "json-handler"
                case "application/xml" return "xml-handler"
                case "text/xml" return "xml-handler"
                case "application/x-www-form-urlencoded" return "form-handler"
                case "multipart/form-data" return "upload-handler"
                default return "default-handler"
        }</handler>
    </dispatch>
```

## API Key Validation

Extract and validate an API key from headers or parameters:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Check multiple locations for the API key :)
let $header-key := exrequest:header("X-API-Key", "")
let $param-key := exrequest:parameter("api_key", "")
let $auth-header := exrequest:header("Authorization", "")
let $bearer-key :=
    if (starts-with($auth-header, "Bearer ")) then
        substring-after($auth-header, "Bearer ")
    else ""

let $api-key :=
    if ($header-key != "") then $header-key
    else if ($param-key != "") then $param-key
    else if ($bearer-key != "") then $bearer-key
    else ""

return
    <auth>
        <key-found>{$api-key != ""}</key-found>
        <source>{
            if ($header-key != "") then "X-API-Key header"
            else if ($param-key != "") then "api_key parameter"
            else if ($bearer-key != "") then "Authorization Bearer"
            else "none"
        }</source>
    </auth>
```

## Request Fingerprint

Create a hash-like fingerprint of a request for caching or deduplication:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $method := exrequest:method()
let $path := exrequest:path()
let $query := exrequest:query()
let $accept := exrequest:header("Accept", "*/*")
let $fingerprint := string-join(($method, $path, $query, $accept), "|")
return
    <fingerprint>
        <components>
            <method>{$method}</method>
            <path>{$path}</path>
            <query>{$query}</query>
            <accept>{$accept}</accept>
        </components>
        <combined>{$fingerprint}</combined>
        <hash>{util:hash($fingerprint, "md5")}</hash>
    </fingerprint>
```

## Session Tracking via Cookies

Read session state from cookies — useful for custom session management:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $session-id := exrequest:cookie("JSESSIONID", "")
let $cookies := exrequest:cookie-names()
return
    <session>
        <has-session>{$session-id != ""}</has-session>
        <session-id>{if ($session-id != "") then $session-id else "none"}</session-id>
        <all-cookies count="{count($cookies)}">
        {
            for $name in $cookies
            return <cookie name="{$name}"/>
        }
        </all-cookies>
    </session>
```

## Full Request Inspector

Combine all Request Module functions into a comprehensive request inspector — useful as a debugging endpoint:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<request-inspector timestamp="{current-dateTime()}">
    <general>
        <method>{exrequest:method()}</method>
        <scheme>{exrequest:scheme()}</scheme>
        <hostname>{exrequest:hostname()}</hostname>
        <port>{exrequest:port()}</port>
        <context-path>{exrequest:context-path()}</context-path>
        <path>{exrequest:path()}</path>
        <query>{exrequest:query()}</query>
        <uri>{exrequest:uri()}</uri>
    </general>
    <connection>
        <server-address>{exrequest:address()}</server-address>
        <remote-address>{exrequest:remote-address()}</remote-address>
        <remote-hostname>{exrequest:remote-hostname()}</remote-hostname>
        <remote-port>{exrequest:remote-port()}</remote-port>
    </connection>
    <headers>
    {
        for $name in exrequest:header-names()
        order by lower-case($name)
        return <header name="{$name}">{exrequest:header($name)}</header>
    }
    </headers>
    <parameters>
    {
        for $name in exrequest:parameter-names()
        let $vals := exrequest:parameter($name)
        return
            <param name="{$name}" count="{count($vals)}">{
                if (string-length(string-join($vals)) > 100) then
                    substring(string-join($vals), 1, 100) || "..."
                else
                    string-join($vals, ", ")
            }</param>
    }
    </parameters>
    <cookies>
    {
        for $name in exrequest:cookie-names()
        return <cookie name="{$name}">{exrequest:cookie($name)}</cookie>
    }
    </cookies>
</request-inspector>
```
