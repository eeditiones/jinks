# Working with Sequences

Sequences are XQuery's fundamental data structure. This chapter covers practical techniques for creating, inspecting, filtering, and transforming sequences.

## Creating and Counting

```xquery
let $seq := ('a', 'b', 'c', 'd', 'e', 'f')
let $count := count($seq)
return
    <results>
        <count>{$count}</count>
        <items>{
            for $item in $seq
            return <item>{$item}</item>
        }</items>
    </results>
```

## Selecting by Position

Access items using positional predicates or `subsequence()`:

```xquery
let $seq := ('a', 'b', 'c', 'd', 'e', 'f')
return (
    $seq[3],
    $seq[position() = (1, 3)],
    subsequence($seq, 2, 2)
)
```

## Finding Items

`index-of()` returns the position(s) where an item appears:

```xquery
let $seq := ('a', 'b', 'c', 'd', 'e', 'f')
return (
    index-of($seq, 'c'),
    index-of($seq, 'x')
)
```

## Aggregate Functions

```xquery
let $basket :=
    <basket>
        <item><type>apples</type><count>2</count></item>
        <item><type>banana</type><count>3</count></item>
        <item><type>pears</type><count>5</count></item>
        <item><type>nuts</type><count>7</count></item>
    </basket>
return (
    sum($basket/item/count),
    avg($basket/item/count),
    min($basket/item/count),
    max($basket/item/count)
)
```

## Detecting Duplicates

Find items that appear more than once using `distinct-values()`:

```xquery
let $seq := ('a', 'b', 'c', 'd', 'e', 'f', 'b', 'c')
let $duplicates :=
    for $item in distinct-values($seq)
    where count($seq[. = $item]) > 1
    return $item
return
    <results>
        <sequence>{string-join($seq, ', ')}</sequence>
        <distinct-values>{string-join(distinct-values($seq), ', ')}</distinct-values>
        <duplicates>{string-join($duplicates, ', ')}</duplicates>
    </results>
```

A more concise approach using `index-of()`:

```xquery
let $values := (3, 4, 6, 6, 2, 7, 3, 1, 2)
return
    <duplicates>{
        for $dup in $values[index-of($values, .)[2]]
        return <duplicate>{$dup}</duplicate>
    }</duplicates>
```

`index-of($values, .)[2]` finds items whose value appears at least twice — `[2]` selects only those with a second occurrence.

## Generating Sequences from Codepoints

Create alphabet sequences using codepoint functions:

```xquery
<letters>{
    let $a := string-to-codepoints('a')
    let $z := string-to-codepoints('z')
    for $letter in ($a to $z)
    return
        codepoints-to-string($letter)
}</letters>
```

## Filtering with Functions

Write reusable functions to filter sequences:

```xquery
declare function local:remove-odd($in as xs:integer*) as xs:integer* {
    $in[. mod 2 = 0]
};

let $thirty := 1 to 30
return
    <results>
        <in>{$thirty}</in>
        <out>{local:remove-odd($thirty)}</out>
    </results>
```

## Sorting, Then Slicing

A common pattern: sort first, then take a subset:

```xquery
let $cities := ("Paris", "Tokyo", "London", "Berlin", "Cairo",
                "Sydney", "Moscow", "Lima", "Seoul", "Oslo",
                "Delhi", "Rome", "Athens", "Bogota", "Dublin")
let $sorted :=
    for $city in $cities
    order by $city
    return $city
return
    <ol>{
        for $city at $count in subsequence($sorted, 1, 10)
        return
            element li {
                attribute class {if ($count mod 2) then 'odd' else 'even'},
                $city
            }
    }</ol>
```
