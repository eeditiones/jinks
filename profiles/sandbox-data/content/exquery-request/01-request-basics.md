# Request Basics

The EXQuery Request Module lets you inspect the incoming HTTP request from within XQuery. It provides functions for reading the HTTP method, URI components, and connection details — everything you need to build request-aware applications.

> **Module namespace:** `http://exquery.org/ns/request`
> **Default prefix:** `exrequest` — avoids collision with eXist's built-in `request` module (`http://exist-db.org/xquery/request`). Both can be used side by side.

> **Note:** These functions require an HTTP request context. They work when your XQuery is invoked via the REST API, URL rewriting (`controller.xq`), or RESTXQ — but will raise `XPDY0002` if called from eXide's direct evaluation (which has no HTTP context). To test these examples, run them through Sandbox's notebook cells, which execute via the REST API.

## HTTP Method

The `exrequest:method()` function returns the HTTP method used for the current request:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

exrequest:method()
```

This returns `POST` because Sandbox executes notebook cells by POSTing the XQuery to the REST API.

## URI Components

Break down the request URI into its individual parts:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<request-uri>
    <scheme>{exrequest:scheme()}</scheme>
    <hostname>{exrequest:hostname()}</hostname>
    <port>{exrequest:port()}</port>
    <path>{exrequest:path()}</path>
    <uri>{exrequest:uri()}</uri>
</request-uri>
```

## Query String

The `exrequest:query()` function returns the raw query string, or the empty sequence if there is none:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $query := exrequest:query()
return
    if (exists($query)) then
        <query-string>{$query}</query-string>
    else
        <no-query-string/>
```

## Context Path

The servlet context path identifies the web application root. For eXist-db, this is typically empty (root context) or `/exist`:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $ctx := exrequest:context-path()
return
    if ($ctx = "") then
        "Root context (no prefix)"
    else
        "Context path: " || $ctx
```

## Connection Details

Inspect the network connection — useful for logging, rate limiting, or access control:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<connection>
    <server-address>{exrequest:address()}</server-address>
    <remote-hostname>{exrequest:remote-hostname()}</remote-hostname>
    <remote-address>{exrequest:remote-address()}</remote-address>
    <remote-port>{exrequest:remote-port()}</remote-port>
</connection>
```

## Full Request Summary

Combine everything into a comprehensive request snapshot:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

<http-request>
    <method>{exrequest:method()}</method>
    <scheme>{exrequest:scheme()}</scheme>
    <host>{exrequest:hostname()}:{exrequest:port()}</host>
    <path>{exrequest:path()}</path>
    <query>{exrequest:query()}</query>
    <context-path>{exrequest:context-path()}</context-path>
    <client>
        <address>{exrequest:remote-address()}</address>
        <hostname>{exrequest:remote-hostname()}</hostname>
        <port>{exrequest:remote-port()}</port>
    </client>
</http-request>
```
