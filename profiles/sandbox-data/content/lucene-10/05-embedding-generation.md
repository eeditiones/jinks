# Embedding Generation

> **Requires eXist-db 7.0+ with Lucene 10.** The `vector:embed` and `vector:embed-batch` functions are part of the Lucene 10 upgrade (PR #6146).

eXist-db can generate vector embeddings using two provider types: **ONNX** for local model inference (no network required) and **HTTP** for remote APIs like OpenAI or Cohere.

## The vector:embed Function

`vector:embed()` converts text to a vector embedding:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $embedding := vector:embed("Hello, world!", "all-MiniLM-L6-v2")
return
    <result>
        <dimensions>{array:size($embedding)}</dimensions>
        <first-values>{array:subarray($embedding, 1, 5)}</first-values>
    </result>
```

The result is an XQuery array of doubles — 384 dimensions for MiniLM models.

## ONNX Provider (Local)

The ONNX provider runs models locally inside the JVM. No API key or network access needed:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

(: Default — uses the model path from conf.xml or built-in registry :)
vector:embed("XQuery is great", "all-MiniLM-L6-v2")

(: Explicit path to model directory :)
vector:embed("XQuery is great", "all-MiniLM-L6-v2", "onnx-models/all-MiniLM-L6-v2")
```

The model directory must contain `model.onnx` and `tokenizer.json`. The path is resolved relative to `exist.home`.

**Built-in ONNX models:**

| Model | Dimensions | Notes |
|-------|-----------|-------|
| `all-MiniLM-L6-v2` | 384 | Good balance of speed and quality |
| `all-MiniLM-L12-v2` | 384 | Higher quality, slower |
| `paraphrase-MiniLM-L3-v2` | 384 | Fastest, lower quality |

## HTTP Provider (Remote API)

For higher-quality embeddings, use a remote API:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

(: OpenAI — requires OPENAI_API_KEY environment variable :)
vector:embed(
    "semantic search with databases",
    "text-embedding-3-small",
    "https://api.openai.com/v1"
)

(: Or pass the API key directly :)
vector:embed(
    "semantic search with databases",
    "text-embedding-3-small",
    "https://api.openai.com/v1",
    "sk-..."
)
```

**Supported HTTP providers:**

| Provider | Models | Dimensions |
|----------|--------|-----------|
| OpenAI | `text-embedding-3-small` (1536), `text-embedding-3-large` (3072) | Set via `dimension` in index config |
| Cohere | `embed-english-v3.0` (1024), `embed-multilingual-v3.0` (1024) | Also light variants (384) |

## Batch Embedding

For embedding multiple texts efficiently, use `vector:embed-batch()`:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

let $texts := ("XQuery basics", "Full-text search", "Vector similarity")
let $embeddings := vector:embed-batch($texts, "all-MiniLM-L6-v2")
return
    <batch>
        <count>{array:size($embeddings)}</count>
        <dimensions>{array:size($embeddings(1))}</dimensions>
    </batch>
```

Batch embedding is significantly faster than embedding texts one at a time, especially with HTTP providers where it reduces the number of API calls.

## Discovering Available Models

List all models known to your eXist-db instance:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

vector:models()
```

For more details, use `vector:diagnostics()`:

```xquery
import module namespace vector = "http://exist-db.org/xquery/vector";

vector:diagnostics()
```

This returns XML elements with each model's ID, source (built-in or registry), path, dimension, and availability status.

## Index-Time Embedding

Instead of pre-computing embeddings, you can configure the index to generate them automatically when documents are stored:

```xquery
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index>
        <lucene>
            <text qname="article">
                <vector-field name="embedding" expression="body"
                    dimension="384" similarity="cosine"
                    embedding="local" model="all-MiniLM-L6-v2"/>
            </text>
        </lucene>
    </index>
</collection>
```

With `embedding="local"`, eXist-db runs the ONNX model at index time — extracting text from the `body` element and storing its vector embedding automatically. No need to compute or store embeddings in your XML documents.
