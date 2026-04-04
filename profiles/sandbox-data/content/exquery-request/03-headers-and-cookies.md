# Headers and Cookies

HTTP headers and cookies carry metadata about the request — content negotiation, authentication tokens, session identifiers, and more. The Request Module gives you direct access to both.

## Listing All Headers

Use `exrequest:header-names()` to discover which headers the client sent:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $names := exrequest:header-names()
return
    <headers count="{count($names)}">
    {
        for $name in $names
        return <header name="{$name}"/>
    }
    </headers>
```

## Reading a Specific Header

The `exrequest:header($name)` function retrieves a header value by name:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<request-headers>
    <host>{exrequest:header("Host")}</host>
    <content-type>{exrequest:header("Content-Type")}</content-type>
    <user-agent>{exrequest:header("User-Agent")}</user-agent>
    <accept>{exrequest:header("Accept")}</accept>
</request-headers>
```

## Header with Default

Use the two-argument form when you need a fallback:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $accept-lang := exrequest:header("Accept-Language", "en")
let $encoding := exrequest:header("Accept-Encoding", "identity")
return
    <negotiation>
        <language>{$accept-lang}</language>
        <encoding>{$encoding}</encoding>
    </negotiation>
```

## Header Map

Get all headers as an XDM map for flexible processing:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $headers := exrequest:header-map()
return
    <header-map>
    {
        for $name in map:keys($headers)
        order by lower-case($name)
        return <header name="{$name}">{$headers($name)}</header>
    }
    </header-map>
```

## Content Negotiation

A practical example — use the `Accept` header to choose the response format:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $accept := exrequest:header("Accept", "*/*")
let $format :=
    if (contains($accept, "application/json")) then "json"
    else if (contains($accept, "text/html")) then "html"
    else if (contains($accept, "application/xml") or contains($accept, "text/xml")) then "xml"
    else "xml"
return
    <content-negotiation>
        <accept-header>{$accept}</accept-header>
        <selected-format>{$format}</selected-format>
    </content-negotiation>
```

## Reading Cookies

Use `exrequest:cookie($name)` to read a specific cookie value:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $session := exrequest:cookie("JSESSIONID", "none")
return
    <cookies>
        <session-id>{$session}</session-id>
    </cookies>
```

## Listing All Cookies

The `exrequest:cookie-names()` function returns all cookie names:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $names := exrequest:cookie-names()
return
    <cookies count="{count($names)}">
    {
        for $name in $names
        return
            <cookie name="{$name}">{exrequest:cookie($name)}</cookie>
    }
    </cookies>
```

## Cookie Map

Get all cookies as a map:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $cookies := exrequest:cookie-map()
return
    if ($cookies instance of map(*)) then
        <cookie-map>
        {
            for $name in map:keys($cookies)
            return <cookie name="{$name}">{$cookies($name)}</cookie>
        }
        </cookie-map>
    else
        <no-cookies/>
```
