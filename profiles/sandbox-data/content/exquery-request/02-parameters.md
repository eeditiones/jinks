# Parameters

The Request Module provides three functions for working with query and form parameters: `parameter-names()` lists all parameter names, `parameter()` retrieves values by name, and `parameter-map()` returns everything as an XDM map.

## Listing Parameter Names

The `exrequest:parameter-names()` function returns a sequence of all parameter names in the request:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $names := exrequest:parameter-names()
return
    <parameters count="{count($names)}">
    {
        for $name in $names
        return <param name="{$name}"/>
    }
    </parameters>
```

Since Sandbox sends the XQuery code as a parameter, you'll see at least one parameter name in the results.

## Reading a Single Parameter

Use `exrequest:parameter($name)` to get the value(s) of a specific parameter:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: The _query parameter contains the XQuery being executed :)
let $query-param := exrequest:parameter("_query")
return
    if (exists($query-param)) then
        <found>The _query parameter is {string-length($query-param)} characters long</found>
    else
        <not-found/>
```

## Default Values

The two-argument form `exrequest:parameter($name, $default)` returns a fallback value when the parameter is absent:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $format := exrequest:parameter("format", "xml")
let $page := exrequest:parameter("page", "1")
let $limit := exrequest:parameter("limit", "10")
return
    <settings>
        <format>{$format}</format>
        <page>{$page}</page>
        <limit>{$limit}</limit>
    </settings>
```

This pattern is useful for optional query parameters with sensible defaults.

## Multi-Valued Parameters

When a parameter appears multiple times (e.g., `?tag=xquery&tag=xml`), `exrequest:parameter()` returns all values as a sequence:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Simulate multi-valued handling :)
let $names := exrequest:parameter-names()
return
    <all-parameters>
    {
        for $name in $names
        let $values := exrequest:parameter($name)
        return
            <param name="{$name}" count="{count($values)}">
            {
                if (string-length(string-join($values)) > 200) then
                    substring(string-join($values), 1, 200) || "..."
                else
                    string-join($values, ", ")
            }
            </param>
    }
    </all-parameters>
```

## Parameter Map

The `exrequest:parameter-map()` function returns all parameters as an XDM map — ideal for functional-style processing:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $params := exrequest:parameter-map()
return
    <parameter-map>
        <is-map>{$params instance of map(*)}</is-map>
        <keys>{string-join(sort(map:keys($params)), ", ")}</keys>
    </parameter-map>
```

## Building a Search Handler

Here's a realistic example — a search endpoint that reads query parameters:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Read search parameters with defaults :)
let $q := exrequest:parameter("q", "")
let $field := exrequest:parameter("field", "all")
let $sort := exrequest:parameter("sort", "relevance")
let $page := xs:integer(exrequest:parameter("page", "1"))
let $per-page := xs:integer(exrequest:parameter("per-page", "20"))
return
    <search-request>
        <query>{if ($q = "") then "(no query provided)" else $q}</query>
        <field>{$field}</field>
        <sort>{$sort}</sort>
        <pagination>
            <page>{$page}</page>
            <per-page>{$per-page}</per-page>
            <offset>{($page - 1) * $per-page}</offset>
        </pagination>
    </search-request>
```
