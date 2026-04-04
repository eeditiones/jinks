# Basic Eval

eXist-db's `/ws/eval` WebSocket endpoint enables real-time query evaluation with streaming results. Instead of the traditional HTTP request/response cycle where the entire result must be buffered in memory, queries stream results as they're produced.

This book demonstrates the XQuery expressions you can evaluate through the endpoint. Each code cell here runs the same XQuery engine that `/ws/eval` uses — so what you see here is exactly what the WebSocket client receives.

## Simple Expressions

The simplest use: evaluate an expression and get the result.

```xquery
1 + 1
```

The client sends `{"action": "eval", "id": "q-1", "query": "1 + 1"}` and receives the result `2`.

## Sequence Results

XQuery naturally produces sequences. The eval endpoint serializes each sequence:

```xquery
(1, 2, 3, 4, 5)
```

## XML Construction

Constructed XML is serialized according to the chosen serialization method:

```xquery
<greeting>
    <message>Hello from WebSocket eval!</message>
    <timestamp>{current-dateTime()}</timestamp>
</greeting>
```

## FLWOR Expressions

FLWOR expressions produce sequences of items that can be streamed incrementally:

```xquery
for $i in 1 to 10
let $square := $i * $i
return
    <number value="{$i}" square="{$square}"/>
```

## String Results

Atomic values serialize directly:

```xquery
let $words := ("WebSocket", "streaming", "evaluation")
return
    string-join($words, " ")
```

## Database Queries

The eval endpoint has full access to the database. Queries against collections work just like any other XQuery context:

```xquery
count(collection("/db")//*)
```

## Error Reporting

When a query produces an error, the endpoint returns structured error information including the error code, message, line number, and column:

```xquery
(: This will produce an XPTY0004 type error :)
1 + "not a number"
```

The error response includes `{"type": "error", "code": "XPTY0004", ...}` with line and column numbers for precise error location.
