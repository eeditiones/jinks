# Practical Recipes

> **Recipes in this chapter use vector search functions that require eXist-db 7.0+ with Lucene 10.** Full-text examples work on any recent eXist-db version.

This chapter shows complete patterns for common search scenarios, combining full-text and vector search.

## Semantic Document Search

The most common use case: embed a user's natural-language query and find semantically similar documents.

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $user-query := "How do I query XML data?"
let $vec := vector:embed($user-query, "all-MiniLM-L6-v2")
return
    for $hit in collection("/db/articles")//article[ft:query-vector(., $vec, 5)]
    let $score := ft:score($hit)
    order by $score descending
    return
        <result score="{$score}">
            <title>{$hit/title/string()}</title>
            <snippet>{substring($hit/body, 1, 150)}...</snippet>
        </result>
```

The user doesn't need to guess the right keywords — "How do I query XML data?" will find articles about XQuery even if they never use the word "query" explicitly.

## Hybrid Search

Combine keyword precision with semantic understanding. Use a full-text filter to narrow candidates, then rank by vector similarity:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $keywords := "search"
let $semantic-query := "finding similar documents using AI"
let $vec := vector:embed($semantic-query, "all-MiniLM-L6-v2")
return
    for $hit in collection("/db/articles")//article[
        ft:query-vector(., $vec, 10, map { "filter-query": $keywords })
    ]
    return
        <result>
            <title>{$hit/title/string()}</title>
            <score>{ft:score($hit)}</score>
        </result>
```

The `filter-query` ensures results contain the keyword "search", while vector similarity determines the ranking. This gives you the best of both worlds.

## RAG Pipeline

Retrieval Augmented Generation (RAG) retrieves relevant context from your database to send alongside a prompt to a language model:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $question := "What are the benefits of full-text search in XML databases?"
let $vec := vector:embed($question, "all-MiniLM-L6-v2")

(: Step 1: Retrieve relevant context :)
let $context :=
    for $hit in collection("/db/articles")//article[ft:query-vector(., $vec, 3)]
    return $hit/body/string()

(: Step 2: Build the prompt with retrieved context :)
let $prompt :=
    "Answer the following question based on the provided context." || "&#10;&#10;" ||
    "Context:" || "&#10;" ||
    string-join($context, "&#10;---&#10;") || "&#10;&#10;" ||
    "Question: " || $question

return
    <rag-prompt>
        <context-docs>{count($context)}</context-docs>
        <prompt>{$prompt}</prompt>
    </rag-prompt>
```

The retrieved context can be sent to any LLM API (OpenAI, Anthropic, etc.) for answer generation. The vector search ensures the most relevant documents are included.

## Faceted Semantic Search

Combine vector search with grouping for faceted navigation:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $vec := vector:embed("data processing and analysis", "all-MiniLM-L6-v2")
let $hits := collection("/db/articles")//article[ft:query-vector(., $vec, 10)]
return
    <search-results total="{count($hits)}">
    {
        for $hit in $hits
        group by $cat := $hit/category/string()
        return
            <facet category="{$cat}" count="{count($hit)}">
            {
                for $article in $hit
                return <title>{$article/title/string()}</title>
            }
            </facet>
    }
    </search-results>
```

## Full-Text Search with KWIC and Scoring

A complete full-text search pattern with snippets, scoring, and pagination — no vector search required:

<!-- context: data -->
```xquery
import module namespace kwic="http://exist-db.org/xquery/kwic";

let $query := "XML databases"
let $page := 1
let $per-page := 10
let $hits :=
    for $hit in collection("data")//article[ft:query(., $query)]
    order by ft:score($hit) descending
    return $hit
return
    <results total="{count($hits)}" page="{$page}">
    {
        for $hit in subsequence($hits, ($page - 1) * $per-page + 1, $per-page)
        return
            <result score="{ft:score($hit)}">
                <title>{$hit/title/string()}</title>
                <author>{$hit/author/string()}</author>
                {kwic:summarize($hit, <config width="80"/>)}
            </result>
    }
    </results>
```

This pattern works on any eXist-db version and provides a solid foundation for search interfaces.

## Multilingual Search via Embeddings

Multilingual embedding models understand text across languages. A query in English can find documents in French, German, or Chinese:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

(: The multilingual model maps all languages to the same vector space :)
let $query-en := vector:embed("machine learning", "embed-multilingual-v3.0",
    "https://api.cohere.ai/v1")

(: This finds relevant documents regardless of language :)
for $hit in collection("/db/multilingual-docs")//doc[ft:query-vector(., $query-en, 5)]
return
    <result lang="{$hit/@xml:lang}">
        <title>{$hit/title/string()}</title>
        <score>{ft:score($hit)}</score>
    </result>
```

This is one of the most powerful advantages of vector search over keyword matching — it works across language boundaries without translation.
