# Cancellation

One of the most important features of `/ws/eval` is the ability to cancel running queries. With the REST API, once a query starts executing, the client has no way to stop it — closing the HTTP connection may or may not terminate server-side execution. With WebSocket eval, cancellation is first-class.

## How Cancellation Works

The client sends `{"action": "cancel", "id": "q-123"}` at any time. The server sets a termination flag on the query's `XQueryWatchDog`. The XQuery engine checks this flag between expression evaluations, and when detected, throws a `TerminatedException` that cleanly aborts the query.

The server responds with:
```json
{"type": "cancelled", "id": "q-123", "items": 50000, "timing": {...}}
```

## Long-Running Queries

This query processes every integer from 1 to a very large number. Via WebSocket eval, you could cancel it after seeing enough results:

```xquery
(: A query that takes a long time to complete.
   Via /ws/eval, the client can cancel it mid-flight. :)
for $i in 1 to 10000
let $factors :=
    for $j in 2 to $i - 1
    where $i mod $j = 0
    return $j
where empty($factors) and $i gt 1
return
    <prime>{$i}</prime>
```

## Automatic Timeout

The `max-execution-time` parameter sets a timeout in milliseconds. The query is automatically cancelled if it exceeds this limit:

```xquery
(: With max-execution-time: 2000, this would be cancelled after 2 seconds.
   The timeout is enforced by the XQueryWatchDog. :)
declare option exist:timeout "2000";

for $i in 1 to 100
return
    <item n="{$i}">{
        (: Simulate work :)
        sum(for $j in 1 to 10000 return $j)
    }</item>
```

## Cancellation During Streaming

If a query is being streamed (chunked results), cancellation can happen between chunks. The client may have already received some result chunks before the cancellation takes effect:

```xquery
(: With chunk-size: 10, the client might receive 3-4 chunks
   before a cancel message takes effect :)
for $i in 1 to 1000
return
    <record id="{$i}">
        <data>{string-join((1 to 100) ! string(.), "-")}</data>
    </record>
```

The cancelled response includes `"items": N` telling the client how many items were produced before cancellation.

## Resource Cleanup

When a query is cancelled (or the WebSocket connection closes), eXist properly cleans up:

- The `DBBroker` is returned to the pool
- `XQueryContext.runCleanupTasks()` is called
- Any open document handles are released
- The query is unregistered from `ProcessMonitor`

This means even if a client disconnects abruptly, no server resources are leaked.
