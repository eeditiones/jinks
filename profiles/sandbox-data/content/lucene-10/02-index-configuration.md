# Index Configuration

Full-text search requires a Lucene index configured via `collection.xconf`. This file tells eXist-db which elements to index and how to analyze their text.

## Basic Configuration

A `collection.xconf` file lives in the database's system collection and applies to all documents in the target collection. Here's the configuration used by our sample articles:

```xquery
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <lucene>
            <analyzer class="org.apache.lucene.analysis.standard.StandardAnalyzer"/>
            <text qname="article">
                <field name="title" expression="title"/>
                <field name="author" expression="author"/>
                <field name="category" expression="category"/>
                <field name="body" expression="body"/>
            </text>
            <text qname="body"/>
            <text qname="title" boost="2.0"/>
        </lucene>
    </index>
</collection>
```

The `<text qname="article">` declaration indexes the full text of each `<article>` element. The nested `<field>` declarations create named fields for targeted queries.

## Querying Named Fields

Named fields let you search specific parts of a document using `ft:query-field()`:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[ft:query-field("title", "XQuery")]
return $hit/title/string()
```

This searches only the `title` field, ignoring matches in the body.

## Combining Field Queries

You can query multiple fields independently:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[
    ft:query-field("author", "Chen") and
    ft:query-field("category", "research")
]
return
    <result>
        <title>{$hit/title/string()}</title>
        <author>{$hit/author/string()}</author>
    </result>
```

## Boosting

The `boost` attribute on a `<text>` element increases that element's weight in scoring. In our configuration, `title` has `boost="2.0"`, meaning title matches score twice as high as body matches:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[ft:query(., "XQuery")]
order by ft:score($hit) descending
return
    <result>
        <title>{$hit/title/string()}</title>
        <score>{ft:score($hit)}</score>
    </result>
```

Articles with "XQuery" in their title rank higher than those with it only in the body.

## Range Indexes

Range indexes enable efficient typed comparisons. Our configuration includes a range index on `<year>`:

<!-- context: data -->
```xquery
collection("data")//article[year >= 2024]/title/string()
```

Without a range index, eXist would compare the string values. The `xs:integer` range index ensures proper numeric comparison.

## Reindexing

After changing a `collection.xconf`, you need to reindex the collection:

```xquery
xmldb:reindex("/db/apps/sandbox/content/lucene-10/data")
```

> **Note:** In eXist 7.0+, `xmldb:reindex()` accepts an optional scope parameter: `"all"` (default), `"fulltext"`, or `"vector"`.
