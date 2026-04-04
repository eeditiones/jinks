# Streaming Large Results

The key advantage of `/ws/eval` over HTTP REST is streaming: results arrive incrementally as they're produced, rather than being buffered entirely in memory before the client sees anything.

## How Streaming Works

When you evaluate a query that produces many items, the endpoint serializes them in **chunks**. Each chunk is sent as a separate WebSocket message with `{"type": "result", "chunk": N, "data": "...", "more": true}`. The final chunk has `"more": false` and includes timing data.

The default chunk size is 1000 items. You can configure it with the `chunk-size` parameter.

## Generating Large Sequences

This query generates 10,000 integers. Via the WebSocket endpoint with `chunk-size: 1000`, the client would receive 10 result messages, each containing 1,000 items:

```xquery
1 to 10000
```

## Chunked XML Results

Streaming works with any item type. Here each chunk contains a batch of XML elements:

```xquery
for $i in 1 to 100
return
    <item n="{$i}">
        <value>{$i * $i}</value>
        <label>Item {$i}</label>
    </item>
```

With `chunk-size: 25`, this produces 4 chunks of 25 elements each.

## Why Chunk Size Matters

Smaller chunks mean faster feedback but more WebSocket messages (overhead). Larger chunks are more efficient but delay initial display.

| Chunk Size | 10K Items | Messages | Best For |
|-----------|-----------|----------|----------|
| 100 | 100 msgs | More overhead | Real-time display |
| 1000 | 10 msgs | Balanced | General use |
| 10000 | 1 msg | No streaming | Batch processing |

## Non-Streaming Mode

Setting `"streaming": false` disables chunking — the entire result is returned in a single message. This is equivalent to the traditional REST API behavior but with WebSocket transport:

```xquery
(: With streaming: false, this returns as a single result message :)
for $i in 1 to 100
return $i
```

## Streaming and Memory

The crucial difference: with HTTP REST, eXist must materialize the entire result `Sequence` before serializing it to the response. With WebSocket streaming, results are serialized chunk-by-chunk from the sequence iterator, allowing the JVM to GC earlier items.

For a query returning 1 million items, REST might need to hold all 1M items in memory simultaneously. WebSocket streaming serializes 1,000 at a time, keeping memory usage bounded.

```xquery
(: This expression generates a large sequence.
   Via REST, it would need to buffer entirely.
   Via /ws/eval with streaming, it arrives in chunks. :)
for $i in 1 to 5000
return
    concat("item-", $i, ": ", string-join((1 to 10) ! string(.), ","))
```
