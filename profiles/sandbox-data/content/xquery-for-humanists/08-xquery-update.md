# XQuery Update

The XQuery Update Facility lets you modify XML data in place. Unlike the functional reconstruction approach (building a new element with selected children), update expressions declaratively describe changes to apply to existing nodes.

## Functional Reconstruction

Before learning the Update Facility, it helps to see the purely functional approach. To add, remove, or replace elements, you reconstruct the parent:

```xquery
let $movie :=
    <movie>
        <title>The Piano</title>
        <director>Jane Campion</director>
        <date>1993</date>
    </movie>
return (
    (: Add a rating :)
    element movie { $movie/*, element rating { "R" } },

    (: Remove the date :)
    element movie { $movie/* except $movie/date },

    (: Replace the title :)
    element movie { <title>Piano, The</title>, $movie/* except $movie/title }
)
```

This works but gets cumbersome for deeply nested changes.

## Copy/Modify/Return

The `copy`/`modify`/`return` expression creates a deep copy and applies update operations to it:

### Insert

```xquery
let $movie :=
    <movie>
        <title>Way of the Dragon</title>
        <director>Bruce Lee</director>
        <date>1972</date>
    </movie>
let $chinese-title := <title alt="Chinese">猛龍過江</title>
return
    copy $new := $movie
    modify
        insert node $chinese-title after $new/title
    return
        $new
```

The `insert node` expression supports several positions: `after`, `before`, `into`, `as first into`, and `as last into`.

### Delete

```xquery
let $movie :=
    <movie>
        <title>Way of the Dragon</title>
        <director>Bruce Lee</director>
        <date>1972</date>
    </movie>
return
    copy $m := $movie
    modify
        delete node $m/date
    return
        $m
```

### Replace

Replace an entire node or just its value:

```xquery
let $movie :=
    <movie>
        <title>Way of the Dragon</title>
        <director>Bruce Lee</director>
        <date>1972</date>
    </movie>
return
    copy $m := $movie
    modify (
        replace node $m/title with <title>Return of the Dragon</title>,
        replace value of node $m/director/text()
            with $m/director/text() || " (1940-1973)"
    )
    return
        $m
```

### Rename

```xquery
let $movie :=
    <movie>
        <title>Way of the Dragon</title>
        <director>Bruce Lee</director>
        <date>1972</date>
    </movie>
return
    copy $m := $movie
    modify
        rename node $m as "film"
    return
        $m
```

## Transform With

XQuery 3.1 introduced `transform with` as a more concise syntax for copy/modify. The context item (`.`) refers to the copy:

```xquery
let $person :=
    <person xml:id="alcuin_of_york">
        <persName>Alcuin of York</persName>
        <residence>
            <placeName><place>Northumbria</place></placeName>
        </residence>
        <birth when="735">c. 735</birth>
        <death when="0804-05-19"/>
    </person>
return
    $person transform with {
        insert node attribute sex { "M" } into .
    }
```

### Multiple Updates

`transform with` can combine multiple update operations in a single expression:

```xquery
let $person :=
    <person xml:id="alcuin_of_york">
        <persName>Alcuin of York</persName>
        <residence>
            <placeName><place>Northumbria</place></placeName>
        </residence>
        <birth when="735">c. 735</birth>
        <death when="0804-05-19"/>
    </person>
return
    $person transform with {
        insert node attribute sex { "M" } into .,
        delete node birth/@when,
        insert node attribute notAfter { "0736" } into birth,
        insert node attribute notBefore { "0734" } into birth,
        rename node residence/placeName/place as "region",
        replace value of node residence/placeName/place
            with "Kingdom of Northumbria"
    }
```

## Updating Functions

Functions that perform update operations must be annotated with `%updating`:

```xquery
declare %updating function local:add-timestamp($doc) {
    if ($doc/book/timestamp) then
        replace value of node $doc/book/timestamp
            with fn:current-dateTime()
    else
        insert node element timestamp {fn:current-dateTime()}
        into $doc/book
};

let $book :=
    <book>
        <title>Version Control: A Novel</title>
        <author>Palmer, Dexter</author>
        <date>2016</date>
    </book>
return
    copy $copy := $book
    modify local:add-timestamp($copy)
    return $copy
```

The `%updating` annotation tells the processor that this function has side effects — it modifies nodes rather than returning new values.
