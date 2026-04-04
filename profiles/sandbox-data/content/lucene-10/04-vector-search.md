# Vector Search

> **Requires eXist-db 7.0+ with Lucene 10.** Vector search functions (`ft:query-vector`, `ft:query-field-vector`) are part of the Lucene 10 upgrade (PR #6146). If you get a "function not defined" error, your eXist-db build does not yet include this feature.

Vector search finds documents by *semantic similarity* rather than keyword matching. Instead of looking for exact words, it compares numerical representations (embeddings) of text. A search for "machine learning" can find documents about "artificial intelligence" even if those exact words never appear.

## What Are Vector Embeddings?

An embedding is a dense array of floating-point numbers — typically 384 to 1536 dimensions — that captures the meaning of a piece of text. Text with similar meaning produces similar vectors.

```xquery
(: A simplified example — real embeddings have hundreds of dimensions :)
let $cat := [0.8, 0.1, 0.9, 0.2]    (: "cat" :)
let $kitten := [0.7, 0.15, 0.85, 0.25] (: "kitten" — similar to cat :)
let $database := [0.1, 0.9, 0.2, 0.8]  (: "database" — very different :)
return
    <similarity>
        <cat-kitten>high</cat-kitten>
        <cat-database>low</cat-database>
    </similarity>
```

## KNN Search with ft:query-vector

The `ft:query-vector()` function performs K-Nearest Neighbor (KNN) search — finding the *k* documents whose vectors are closest to a query vector:

```xquery
(: Search for the 3 most similar articles to a query vector :)
let $query-vec := vector:embed("semantic search with databases", "all-MiniLM-L6-v2")
return
    for $hit in collection("/db/articles")//article[ft:query-vector(., $query-vec, 3)]
    return
        <result>
            <title>{$hit/title/string()}</title>
            <score>{ft:score($hit)}</score>
        </result>
```

The function signature:

- `$nodes` — the node set to search
- `$vector` — the query vector (an XQuery array of floats)
- `$k` — how many nearest neighbors to return (default: 10)

Results are ordered by similarity, and `ft:score()` returns the similarity score.

## Field-Based Vector Search

Like `ft:query-field()` for text, `ft:query-field-vector()` searches a specific named vector field:

```xquery
let $query-vec := vector:embed("REST API development", "all-MiniLM-L6-v2")
return
    for $hit in collection("/db/articles")//article[
        ft:query-field-vector("embedding", $query-vec, 5)
    ]
    return
        <result>
            <title>{$hit/title/string()}</title>
            <score>{ft:score($hit)}</score>
        </result>
```

## Filtered Vector Search

Combine vector search with full-text or range filters using the options parameter:

```xquery
let $query-vec := vector:embed("search technology", "all-MiniLM-L6-v2")
return
    for $hit in collection("/db/articles")//article[
        ft:query-vector(., $query-vec, 5, map {
            "filter-query": "XML"
        })
    ]
    return
        <result>
            <title>{$hit/title/string()}</title>
            <score>{ft:score($hit)}</score>
        </result>
```

The `filter-query` option applies a full-text filter *before* the vector search, so only articles matching "XML" are considered for similarity ranking. This is the key to **hybrid search** — combining keyword precision with semantic understanding.

## Similarity Functions

The `similarity` attribute in the index configuration controls how vectors are compared:

| Function | Best for | Score range |
|----------|----------|-------------|
| `cosine` (default) | General text similarity | 0 to 1 |
| `euclidean` | Spatial distance | 0 to ∞ (lower = closer) |
| `dot_product` | Normalized vectors | -1 to 1 |

Cosine similarity is the most common choice for text embeddings — it measures the angle between vectors, ignoring magnitude.
