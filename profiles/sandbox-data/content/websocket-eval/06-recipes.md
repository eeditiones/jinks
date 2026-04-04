# Practical Recipes

This chapter shows practical patterns for using the `/ws/eval` endpoint effectively: parameterized queries, module imports, serialization options, and monitoring.

## Parameterized Queries

External variables let clients pass parameters without string interpolation (which risks injection). The client sends variables as `{"variables": {"name": "value"}}`:

```xquery
(: Client sends: {"variables": {"search": "hamlet", "limit": "10"}} :)
declare variable $search external;
declare variable $limit external;

for $speech in collection("/db")//SPEECH[contains(LINE, $search)]
let $play := $speech/ancestor::PLAY/TITLE/text()
return
    <match play="{$play}" speaker="{$speech/SPEAKER}">
        {$speech/LINE[contains(., $search)]}
    </match>
```

Variables arrive as strings. Cast them when needed:

```xquery
(: The "limit" variable arrives as a string — cast to integer :)
declare variable $limit external := "10";

(1 to xs:integer($limit))
```

## Module Imports

Set `module-load-path` to resolve relative module imports. This is essential for queries that use application-specific libraries:

```xquery
(: With module-load-path: "/db/apps/myapp/modules" :)
import module namespace util = "http://myapp.com/util"
    at "util.xqm";

util:format-date(current-date())
```

The `module-load-path` parameter is equivalent to setting the module resolution base URI in the XQuery context.

## Serialization Options

The `serialization` parameter controls output format. Common options:

### XML (default)

```xquery
(: serialization: {"method": "xml", "indent": "yes"} :)
<root>
    <items>{
        for $i in 1 to 3
        return <item n="{$i}"/>
    }</items>
</root>
```

### JSON

For data exchange with JavaScript clients:

```xquery
(: serialization: {"method": "json"} :)
<json type="object">
    <status>ok</status>
    <count type="number">42</count>
    <items type="array">
        <item type="object">
            <name>Alpha</name>
            <value type="number">1</value>
        </item>
    </items>
</json>
```

### Adaptive

The most flexible method — handles maps, arrays, atomic values, and XML natively:

```xquery
(: serialization: {"method": "adaptive"} :)
map {
    "greeting": "Hello",
    "numbers": array { 1 to 5 },
    "nested": map {
        "key": "value"
    }
}
```

### Text

For plain string output:

```xquery
(: serialization: {"method": "text"} :)
string-join(
    for $i in 1 to 5
    return concat("Line ", $i, ": data"),
    "&#10;"
)
```

## Context Collection

The `context` parameter sets the base collection for resolving relative document/collection paths:

```xquery
(: With context: "/db/apps/myapp" :)
(: These relative paths resolve against /db/apps/myapp :)
doc("data/config.xml")/config/setting[@name="title"]/@value
```

## Monitoring Active Queries

Admin clients can subscribe to the `_monitor` channel on `/ws` to see all running queries. The server broadcasts lifecycle events (`started`, `progress`, `completed`, `error`, `cancelled`) and periodic snapshots of all active queries from the ProcessMonitor.

Here's an XQuery view of what the monitor sees:

```xquery
(: This is what the _monitor channel broadcasts as JSON snapshots :)
let $queries := system:get-running-xqueries()
return
    <monitor timestamp="{current-dateTime()}">{
        for $q in $queries//query
        return
            <query id="{$q/@id}">
                <user>{$q/@user/string()}</user>
                <source>{substring($q/source/text(), 1, 100)}</source>
                <elapsed>{$q/@elapsed/string()}ms</elapsed>
            </query>
    }</monitor>
```

## Admin Cancel

DBA users can cancel any running query by sending `{"action": "admin-cancel", "id": "CONTEXT_HASH"}` where the ID is the identity hash code of the query's XQueryContext (available from the monitor snapshot). This is the same mechanism as `system:kill-running-xquery()`:

```xquery
(: List running queries with their cancellable IDs :)
system:get-running-xqueries()
```

## Putting It All Together

A typical interactive session combines several features: streaming results, monitoring progress, and having the option to cancel:

```xquery
(: A real-world query: analyze all documents in a collection :)
(: Via /ws/eval with streaming, the client sees results incrementally :)
(: Via _monitor, an admin dashboard shows it running :)
(: Via cancel, the user can stop it if it takes too long :)

declare variable $collection external := "/db";

for $resource in xmldb:get-child-resources($collection)
let $doc := doc(concat($collection, "/", $resource))
let $elements := count($doc//*)
let $attributes := count($doc//@*)
order by $elements descending
return
    <document name="{$resource}"
              elements="{$elements}"
              attributes="{$attributes}"
              size="{xmldb:size($collection, $resource)}"/>
```
