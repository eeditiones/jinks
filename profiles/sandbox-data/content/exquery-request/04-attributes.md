# Request Attributes

Request attributes are key-value pairs stored on the HTTP request object. Unlike parameters (which come from the URL or form data), attributes are set programmatically — by servlets, filters, URL rewriting, or your own XQuery code. They're useful for passing data between processing stages.

## Setting and Getting Attributes

Use `exrequest:set-attribute()` to store a value, and `exrequest:attribute()` to retrieve it:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Set some attributes :)
let $_ := (
    exrequest:set-attribute("app.user", "admin"),
    exrequest:set-attribute("app.role", "editor"),
    exrequest:set-attribute("app.start-time", string(current-dateTime()))
)
return
    <attributes>
        <user>{exrequest:attribute("app.user")}</user>
        <role>{exrequest:attribute("app.role")}</role>
        <start-time>{exrequest:attribute("app.start-time")}</start-time>
    </attributes>
```

## set-attribute Returns Empty

The `exrequest:set-attribute()` function returns the empty sequence, making it safe to use in `let` bindings or sequence expressions without affecting your result:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $_ := exrequest:set-attribute("key", "value")
return
    <result>
        <set-result-empty>{empty($_ )}</set-result-empty>
        <value>{exrequest:attribute("key")}</value>
    </result>
```

## Default Values

The two-argument form of `exrequest:attribute()` provides a fallback:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $theme := exrequest:attribute("app.theme", "light")
let $lang := exrequest:attribute("app.language", "en")
return
    <preferences>
        <theme>{$theme}</theme>
        <language>{$lang}</language>
    </preferences>
```

## Listing Attribute Names

The `exrequest:attribute-names()` function returns all attribute names:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Set some test attributes :)
let $_ := (
    exrequest:set-attribute("x", "1"),
    exrequest:set-attribute("y", "2"),
    exrequest:set-attribute("z", "3")
)
let $names := exrequest:attribute-names()
return
    <attribute-names count="{count($names)}">
    {
        for $name in $names
        return <attr name="{$name}">{exrequest:attribute($name)}</attr>
    }
    </attribute-names>
```

## Attribute Map

Get all attributes as an XDM map with `exrequest:attribute-map()`:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

let $_ := (
    exrequest:set-attribute("config.debug", "true"),
    exrequest:set-attribute("config.version", "1.0"),
    exrequest:set-attribute("config.environment", "development")
)
let $attrs := exrequest:attribute-map()
return
    <attribute-map is-map="{$attrs instance of map(*)}">
    {
        for $key in map:keys($attrs)
        where starts-with($key, "config.")
        order by $key
        return <attr key="{$key}">{$attrs($key)}</attr>
    }
    </attribute-map>
```

## Passing Context Between Stages

Attributes are ideal for passing computed context from `controller.xq` or a filter to the target XQuery. Here's a simulation:

```xquery
import module namespace exrequest = "http://exquery.org/ns/request";

(: Stage 1: A controller or filter sets context :)
let $_ := (
    exrequest:set-attribute("route.collection", "/db/apps/myapp"),
    exrequest:set-attribute("route.action", "list"),
    exrequest:set-attribute("route.format", "xml"),
    exrequest:set-attribute("auth.user", "jdoe"),
    exrequest:set-attribute("auth.permissions", "read,write")
)

(: Stage 2: The target XQuery reads the context :)
let $collection := exrequest:attribute("route.collection")
let $action := exrequest:attribute("route.action")
let $user := exrequest:attribute("auth.user")
let $permissions := tokenize(exrequest:attribute("auth.permissions"), ",")
return
    <handler>
        <collection>{$collection}</collection>
        <action>{$action}</action>
        <user>{$user}</user>
        <permissions>
        {
            for $perm in $permissions
            return <permission>{$perm}</permission>
        }
        </permissions>
    </handler>
```
