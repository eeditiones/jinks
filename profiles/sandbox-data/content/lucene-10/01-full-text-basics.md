# Full-Text Search Basics

eXist-db includes a powerful full-text search engine built on Apache Lucene. Unlike simple string matching with `contains()`, full-text search understands word boundaries, handles stemming, ignores case, and ranks results by relevance.

## Your First Full-Text Query

The `ft:query()` function searches indexed nodes. It takes a node set and a query string:

<!-- context: data -->
```xquery
collection("data")//article[ft:query(body, "search")]
```

This returns all articles whose body contains the word "search". Lucene tokenizes the text and matches whole words — unlike `contains()`, which would also match "researcher".

## Keyword Search

Search for multiple words. By default, Lucene treats them as OR — any word matches:

<!-- context: data -->
```xquery
for $hit in collection("data")//article[ft:query(body, "XML databases")]
return
    <result>
        <title>{$hit/title/string()}</title>
        <score>{ft:score($hit)}</score>
    </result>
```

The `ft:score()` function returns a relevance score. Articles containing both "XML" and "databases" score higher than those with only one term.

## Requiring All Terms

Use `+` to require a term, or wrap the query in quotes for an exact phrase:

<!-- context: data -->
```xquery
(: All terms required with AND :)
for $hit in collection("data")//article[ft:query(body, "XML AND databases")]
order by ft:score($hit) descending
return
    <result>
        <title>{$hit/title/string()}</title>
        <score>{ft:score($hit)}</score>
    </result>
```

## Phrase Search

Enclose terms in double quotes to match an exact phrase:

<!-- context: data -->
```xquery
collection("data")//article[ft:query(body, '"full-text search"')]/title
```

This only matches articles where "full-text search" appears as a contiguous phrase.

## Wildcards

Use `*` for any number of characters or `?` for a single character:

<!-- context: data -->
```xquery
collection("data")//article[ft:query(body, "semant*")]/title
```

This matches "semantic", "semantics", "semantically", etc.

## Fuzzy Matching

Append `~` to a term for fuzzy matching, which finds words within an edit distance:

<!-- context: data -->
```xquery
collection("data")//article[ft:query(body, "qurey~")]/title
```

Even though "qurey" is misspelled, fuzzy matching finds articles containing "query".

## KWIC Snippets

Keyword-in-context (KWIC) snippets show search terms highlighted within their surrounding text:

<!-- context: data -->
```xquery
import module namespace kwic="http://exist-db.org/xquery/kwic";

for $hit in collection("data")//article[ft:query(body, "search")]
return
    <result>
        <title>{$hit/title/string()}</title>
        {kwic:summarize($hit, <config width="60"/>)}
    </result>
```

The `kwic:summarize()` function extracts a snippet around each match, with the search term wrapped in `<exist:match>` tags. The `width` attribute controls how many characters of context to show on each side.
