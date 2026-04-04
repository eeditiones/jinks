# Serialization Options

Each code cell can declare serialization options using Pandoc-style fenced code block attributes. The options control how query results are formatted.

## Default (Adaptive)

Without any attributes, results use adaptive serialization — eXist-db's default that auto-detects the best format:

```xquery
map { "name": "eXist", "version": 7, "features": ["xquery", "xpath", "xslt"] }
```

## JSON Output

Use `{method=json}` to format results as JSON:

```xquery {method=json}
map { "name": "eXist", "version": 7, "features": ["xquery", "xpath", "xslt"] }
```

## JSON with Indentation

Add `indent=yes` for pretty-printed output:

```xquery {method=json indent=yes}
map {
    "name": "eXist",
    "version": 7,
    "features": array { "xquery", "xpath", "xslt" },
    "config": map {
        "port": 8080,
        "ssl": false()
    }
}
```

## XML Output

Use `{method=xml}` for XML serialization:

```xquery {method=xml}
<config>
    <version>7.0</version>
    <features>
        <feature>xquery</feature>
        <feature>xpath</feature>
    </features>
</config>
```

## XML with Indentation

```xquery {method=xml indent=yes}
<library>
{
    for $i in 1 to 3
    return
        <book id="{$i}">
            <title>Book {$i}</title>
            <year>{2020 + $i}</year>
        </book>
}
</library>
```

## Text Output

Use `{method=text}` for plain text, with an optional `item-separator`:

```xquery {method=text}
for $i in 1 to 5
return "Item " || $i
```

## Comparing Serializations

Run these cells to see the same data in different formats:

```xquery {method=adaptive}
(1, "hello", <x/>, map {"a": 1}, [1,2,3])
```

```xquery {method=json}
[1, "hello", "<x/>", {"a": 1}, [1,2,3]]
```
