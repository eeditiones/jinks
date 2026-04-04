# Query, Form, Header, and Cookie Parameters

Beyond path variables and request bodies, RESTXQ can bind query string parameters, form fields, HTTP headers, and cookies to function parameters.

## Query parameters

The `%rest:query-param` annotation binds URL query string values:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: GET /api/search?q=xquery&limit=10 :)
declare
    %rest:path("/api/search")
    %rest:GET
    %rest:query-param("q", "{$query}")
    %rest:query-param("limit", "{$limit}", 20)
    %output:method("json")
    %output:media-type("application/json")
function api:search($query as xs:string, $limit as xs:integer) {
    map {
        "query": $query,
        "limit": $limit,
        "results": array { "result 1", "result 2", "result 3" }
    }
};
```

The annotation `%rest:query-param("q", "{$query}")` means: take the `q` query parameter and bind it to the `$query` function parameter. The third argument (`20` in the `limit` case) provides a default value if the parameter is missing.

## Multiple values

A query parameter can appear multiple times. Declare the function parameter with `*` cardinality to accept all values:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: GET /api/filter?tag=xquery&tag=tutorial&tag=exist :)
declare
    %rest:path("/api/filter")
    %rest:GET
    %rest:query-param("tag", "{$tags}")
    %output:method("json")
    %output:media-type("application/json")
function api:filter($tags as xs:string*) {
    map {
        "tag-count": count($tags),
        "tags": array { $tags }
    }
};
```

Requesting `/api/filter?tag=xquery&tag=tutorial` returns `{"tag-count":2,"tags":["xquery","tutorial"]}`.

## Form parameters

For HTML form submissions (`application/x-www-form-urlencoded`), use `%rest:form-param`:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

(: POST with form body: username=alice&password=secret :)
declare
    %rest:path("/api/login")
    %rest:POST
    %rest:form-param("username", "{$user}")
    %rest:form-param("password", "{$pass}")
    %output:method("json")
    %output:media-type("application/json")
function api:login($user as xs:string, $pass as xs:string) {
    map {
        "user": $user,
        "authenticated": $user = "admin",
        "message":
            if ($user = "admin") then "Welcome back!"
            else "Unknown user: " || $user
    }
};
```

## Header parameters

Bind HTTP request headers with `%rest:header-param`:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/whoami")
    %rest:GET
    %rest:header-param("User-Agent", "{$ua}", "unknown")
    %rest:header-param("Accept-Language", "{$lang}", "en")
    %output:method("json")
    %output:media-type("application/json")
function api:whoami($ua as xs:string, $lang as xs:string) {
    map {
        "user-agent": $ua,
        "language": $lang
    }
};
```

## Cookie parameters

Bind cookie values with `%rest:cookie-param`:

```xquery
xquery version "3.1";

module namespace api = "http://example.com/api";

declare namespace rest = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

declare
    %rest:path("/api/session")
    %rest:GET
    %rest:cookie-param("session_id", "{$session}", "none")
    %output:method("json")
    %output:media-type("application/json")
function api:session-info($session as xs:string) {
    map {
        "session": $session,
        "active": $session != "none"
    }
};
```

## Parameter validation errors

RESTXQ validates parameters at bind time. Common errors:

- **Missing required parameter** (no default): returns empty sequence
- **Type mismatch** (e.g., `$x as xs:integer` with value `"abc"`): returns 500
- **Cardinality mismatch** (e.g., `$x as item()` with multiple values): returns 500

> **Note:** `%rest:form-param`, `%rest:header-param`, and `%rest:cookie-param` are BaseX extensions to the RESTXQ spec. The core spec only defines `%rest:query-param`. eXist-db's native RESTXQ supports all four.
