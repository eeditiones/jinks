# Timing Breakdown

The `/ws/eval` endpoint provides precise timing for each phase of query execution. This visibility is invaluable for understanding where time is spent — is it parsing, compiling, evaluating, or serializing?

## Timing Phases

Every completed query returns a timing object:

```json
{
    "timing": {
        "parse": 2,
        "compile": 15,
        "evaluate": 1234,
        "serialize": 89,
        "total": 1340
    }
}
```

All values are in milliseconds.

| Phase | What Happens |
|-------|-------------|
| **parse** | ANTLR lexer/parser produces the AST |
| **compile** | AST is walked to build the expression tree, static analysis |
| **evaluate** | The expression tree is evaluated against the database |
| **serialize** | Results are converted to the output format (XML, JSON, adaptive) |

## Fast Parse, Slow Eval

Most queries spend their time in evaluation — the actual database work:

```xquery
(: Parse: ~1ms, Compile: ~2ms, Evaluate: most of the time :)
for $play in collection("/db")//PLAY
let $speeches := $play//SPEECH
return
    <play title="{$play/TITLE}">
        <speech-count>{count($speeches)}</speech-count>
    </play>
```

## Compile-Heavy Queries

Complex queries with many function declarations or deeply nested FLWOR expressions take longer to compile:

```xquery
(: The compilation phase builds the expression tree
   for all these function definitions :)
declare function local:factorial($n as xs:integer) as xs:integer {
    if ($n le 1) then 1
    else $n * local:factorial($n - 1)
};

declare function local:fibonacci($n as xs:integer) as xs:integer {
    if ($n le 1) then $n
    else local:fibonacci($n - 1) + local:fibonacci($n - 2)
};

declare function local:is-prime($n as xs:integer) as xs:boolean {
    $n gt 1 and
    empty(
        for $i in 2 to xs:integer(math:sqrt($n))
        where $n mod $i = 0
        return $i
    )
};

<results>
    <factorial-10>{local:factorial(10)}</factorial-10>
    <fibonacci-10>{local:fibonacci(10)}</fibonacci-10>
    <primes-under-50>{
        for $i in 2 to 50
        where local:is-prime($i)
        return <prime>{$i}</prime>
    }</primes-under-50>
</results>
```

## Serialize-Heavy Queries

When evaluation is fast but the result is large, serialization dominates:

```xquery
(: Evaluate: fast (range sequence), Serialize: slow (large output) :)
for $i in 1 to 5000
return
    <item id="{$i}">
        <data>{string-join(for $j in 1 to 20 return concat("field", $j, "=value", $j), "; ")}</data>
    </item>
```

## Progress Messages

During execution, the server sends progress messages as the query transitions between phases:

```
{"type": "progress", "id": "q-1", "phase": "parsing", "items": 0, "elapsed": 0}
{"type": "progress", "id": "q-1", "phase": "compiling", "items": 0, "elapsed": 2}
{"type": "progress", "id": "q-1", "phase": "evaluating", "items": 0, "elapsed": 5}
{"type": "progress", "id": "q-1", "phase": "serializing", "items": 0, "elapsed": 120}
```

Clients can display these as a status bar or progress indicator: "Parsing... Compiling... Evaluating... Serializing..."

## Using Timing for Optimization

If timing shows evaluation is the bottleneck, optimize the XQuery logic or add indexes. If serialization is slow, consider a more compact output format or streaming with smaller chunks.

```xquery
(: Compare: XML serialization vs. string output :)
(: The serialization phase is faster with simple string output :)
for $i in 1 to 1000
return
    concat($i, ": ", $i * $i)
```
