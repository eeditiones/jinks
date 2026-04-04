# Migration from Lucene 4

eXist-db 7.0 upgrades from Apache Lucene 4.x to Lucene 10.3. This is a major version jump that brings new capabilities while maintaining backward compatibility for most existing queries.

## What Changed

**New features:**
- Vector KNN search (`ft:query-vector`, `ft:query-field-vector`)
- Embedding generation (`vector:embed`, `vector:embed-batch`)
- Dedicated vector storage (`vector.dbx`)
- Scoped reindexing (`xmldb:reindex($col, "fulltext")`)

**Preserved:**
- `ft:query()` syntax and behavior
- `ft:query-field()` field queries
- `ft:score()` scoring
- KWIC snippet generation
- Boolean, wildcard, fuzzy, and phrase queries
- Index configuration format (with new `<vector-field>` additions)

**Changed:**
- Internal index format (requires reindex)
- Some edge-case scoring differences (Lucene's BM25 scoring refinements)
- Minimum Java version: Java 11+ (already required by eXist 6.x)

## Reindexing After Upgrade

The Lucene index format is not backward-compatible across major versions. After upgrading to eXist 7.0, you must reindex all collections with Lucene indexes:

```xquery
(: Reindex a specific collection :)
xmldb:reindex("/db/apps/myapp/data")
```

For large databases, you can reindex selectively:

```xquery
(: Reindex only full-text fields — faster if you don't have vector indexes :)
xmldb:reindex("/db/apps/myapp/data", "fulltext")

(: Reindex only vector fields :)
xmldb:reindex("/db/apps/myapp/data", "vector")

(: Reindex everything — text + vectors :)
xmldb:reindex("/db/apps/myapp/data", "all")
```

## Adding Vector Search to Existing Indexes

You can add `<vector-field>` declarations to your existing `collection.xconf` without removing your text field definitions:

```xquery
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index>
        <lucene>
            <text qname="article">
                <!-- Existing text fields — unchanged -->
                <field name="title" expression="title"/>
                <field name="body" expression="body"/>

                <!-- New: vector field for semantic search -->
                <vector-field name="embedding" expression="body"
                    dimension="384" similarity="cosine"
                    embedding="local" model="all-MiniLM-L6-v2"/>
            </text>
        </lucene>
    </index>
</collection>
```

After updating the configuration, reindex the collection to populate the new vector index:

```xquery
xmldb:reindex("/db/apps/myapp/data", "vector")
```

## Vector Storage Options

The `vector-store` attribute on `<lucene>` controls where vectors are persisted:

```xquery
<!-- Default: store in both Lucene index and vector.dbx -->
<lucene vector-store="db">

<!-- Lucene only: no vector.dbx file -->
<lucene vector-store="lucene">
```

The `db` option (default) stores vectors in a dedicated `vector.dbx` file alongside the Lucene index. This enables faster reindexing because vectors can be read from `vector.dbx` instead of re-extracting and re-embedding from source documents.

## Pre-Computed vs Index-Time Embeddings

**Index-time embedding** (recommended for most cases):

```xquery
<vector-field name="embedding" expression="body"
    embedding="local" model="all-MiniLM-L6-v2"
    dimension="384"/>
```

eXist generates embeddings automatically when documents are stored or updated.

**Pre-computed embeddings** (for custom models or offline workflows):

```xquery
<vector-field name="embedding" expression="embedding"
    dimension="384" encoding="base64"/>
```

Your documents include the embedding directly:

```xquery
<article>
    <title>Example</title>
    <body>Article text here.</body>
    <embedding>SGVsbG8gV29ybGQ=...</embedding>
</article>
```

The `encoding` attribute specifies how the vector is stored in XML: `base64` (little-endian float32 bytes) or `text` (space-separated floats).

## Bug Fixes in Lucene 10

The upgrade resolves several long-standing issues:

- **#4389** — Incorrect match highlighting with certain analyzer configurations
- **#4539** — Range index comparison failures with edge-case values
- **#4835** — Memory leak during large reindex operations
- **#3977** — Inconsistent scoring across collection boundaries
- **#4074** — Wildcard queries failing on fields with custom analyzers
- **#4881** — KWIC snippets truncating multi-byte characters
- **#6012** — Index corruption after concurrent write operations

If you've encountered any of these issues, upgrading to eXist 7.0 with Lucene 10 resolves them.

## Verifying Your Installation

Check that vector search is available:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

<status>
    <lucene-module>{exists(function-lookup(xs:QName("ft:query"), 3))}</lucene-module>
    <vector-module>{exists(function-lookup(xs:QName("vector:models"), 0))}</vector-module>
    <available-models>{string-join(vector:models(), ", ")}</available-models>
    <diagnostics>{vector:diagnostics()}</diagnostics>
</status>
```

If `vector-module` returns `false`, your eXist-db build does not include the vector extension.
