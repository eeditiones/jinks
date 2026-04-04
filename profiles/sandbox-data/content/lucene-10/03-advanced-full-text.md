# Advanced Full-Text Queries

Beyond basic keyword search, Lucene supports boolean logic, range constraints, faceted search, and query options that give you fine-grained control over search behavior.

## Boolean Queries

Combine terms with `AND`, `OR`, and `NOT`:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[ft:query(body, "XML AND NOT humanities")]
return $hit/title/string()
```

This finds articles mentioning XML but not in the context of humanities.

## Proximity Search

Find words within a certain distance of each other using `~` after a phrase:

<!-- context: data -->
```xquery
collection("data")//article[ft:query(body, '"XML databases"~3')]/title/string()
```

This matches "XML databases", "XML and databases", or any occurrence where the two words are within 3 positions of each other.

## Query Options

The third argument to `ft:query()` accepts an XML element or map with query options:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[
    ft:query(body, "search", map {
        "leading-wildcard": "yes",
        "filter-rewrite": "yes"
    })
]
return $hit/title/string()
```

Common options:

| Option | Default | Description |
|--------|---------|-------------|
| `leading-wildcard` | `no` | Allow wildcards at the start of terms (`*query`) |
| `filter-rewrite` | `yes` | Use filter rewrite for better wildcard performance |
| `default-operator` | `or` | Default boolean operator (`or` or `and`) |

## Combining Full-Text and Range Queries

Use both full-text search and range index predicates together:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[
    ft:query(body, "search") and year >= 2024
]
order by ft:score($hit) descending
return
    <result>
        <title>{$hit/title/string()}</title>
        <year>{$hit/year/string()}</year>
        <score>{ft:score($hit)}</score>
    </result>
```

eXist optimizes this by applying the Lucene query first, then filtering by the range predicate.

## Field-Specific Boolean Queries

Combine field queries with different terms:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[
    ft:query-field("body", "vector OR embedding") and
    ft:query-field("category", "research")
]
return
    <result>
        <title>{$hit/title/string()}</title>
        <category>{$hit/category/string()}</category>
    </result>
```

## Aggregation with group by

Combine full-text search with XQuery grouping for faceted results:

<!-- context: data -->
```xquery
let $hits := collection("data")//article[ft:query(., "XML OR search")]
for $hit in $hits
group by $category := $hit/category/string()
order by count($hit) descending
return
    <facet category="{$category}" count="{count($hit)}">
    {
        for $article in $hit
        return <title>{$article/title/string()}</title>
    }
    </facet>
```

This groups search results by category — a simple form of faceted navigation.

## Highlighting Matches

For richer highlighting than KWIC, use `util:expand()` to see exactly where Lucene matched within the XML:

<!-- context: data -->
```xquery
let $hit := collection("data")//article[ft:query(body, "semantic")][1]
return util:expand($hit)
```

The expanded result wraps matched terms in `<exist:match>` elements, preserving the original XML structure. This is useful for building custom highlighting in your application.
