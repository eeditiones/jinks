# Sequence Functions

FunctX fills gaps in XQuery's built-in sequence operations, especially for atomic value comparisons (where built-in `intersect`, `union`, `except` only work on nodes).

## Sorting

`functx:sort()` saves you from writing a full FLWOR just to sort:

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:sort(('c', 'a', 'b')),
    functx:sort((3, 1, 4, 1, 5, 9, 2, 6))
)
```

**Expected:** `("a", "b", "c")`, `(1, 1, 2, 3, 4, 5, 6, 9)`

## Set Operations on Values

XQuery's `union`, `intersect`, and `except` work on *nodes*. FunctX provides equivalents for *atomic values*:

```xquery
import module namespace functx = "http://www.functx.com";

let $a := (1, 2, 3, 4, 5)
let $b := (3, 4, 5, 6, 7)
return (
    <union>{functx:value-union($a, $b)}</union>,
    <intersect>{functx:value-intersect($a, $b)}</intersect>,
    <except>{functx:value-except($a, $b)}</except>
)
```

**Expected:** union `(1,2,3,4,5,6,7)`, intersect `(3,4,5)`, except `(1,2)`

## Deep Distinct

`fn:distinct-values()` works on atomic values. `functx:distinct-deep()` works on XML nodes, comparing their full content:

```xquery
import module namespace functx = "http://www.functx.com";

let $authors :=
    <authors>
        <author><fName>Kate</fName><lName>Jones</lName></author>
        <author><fName>Kate</fName><lName>Jones</lName></author>
        <author><fName>Kate</fName><lName>Doe</lName></author>
    </authors>
return (
    count($authors/author),
    count(functx:distinct-deep($authors/author))
)
```

**Expected:** `3`, `2` (the duplicate Kate Jones is removed)

## Testing Node Membership

```xquery
import module namespace functx = "http://www.functx.com";

let $authors :=
    <authors>
        <author><fName>Kate</fName><lName>Jones</lName></author>
        <author><fName>John</fName><lName>Doe</lName></author>
    </authors>
let $test := <author><fName>John</fName><lName>Doe</lName></author>
return (
    (: Node identity — false because $test is a different node :)
    $test = $authors/author,
    (: Deep equality — true because content matches :)
    functx:is-node-in-sequence-deep-equal($test, $authors/author)
)
```

## Are Values Distinct?

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:are-distinct-values(('a', 'b', 'c')),
    functx:are-distinct-values(('a', 'b', 'a'))
)
```

**Expected:** `true`, `false`
