# XQuery 3.0 Features

XQuery 3.0 introduced several features that make the language more expressive and concise. This chapter covers string operators, switch expressions, error handling, and the group by clause.

## String Concatenation

The `||` operator concatenates strings — a more readable alternative to `concat()`:

```xquery
let $who := "world"
return
    "Hello " || $who || "!"
```

## The Simple Map Operator (!)

The bang operator `!` evaluates an expression for each item in a sequence, setting the context item (`.`) to the current item:

```xquery
("Hello", "world") ! upper-case(.)
```

This is more concise than writing a `for` expression when you just need to transform each item.

## Switch Expression

The `switch` expression matches a value against multiple cases:

```xquery
let $animal := "Duck"
return
    switch ($animal)
        case "Cow" return "Moo"
        case "Cat" return "Meow"
        case "Duck" return "Quack"
        case "Dog" case "Pitbull" return "Wuff"
        default return "What's that odd noise?"
```

Note that multiple cases can share the same return clause, as shown with "Dog" and "Pitbull".

## Try/Catch

Handle errors gracefully with `try`/`catch`:

```xquery
let $x := "Hello"
return
    try {
        $x cast as xs:integer
    } catch * {
        <error>Caught error {$err:code}: {$err:description}</error>
    }
```

The `catch *` clause catches any error. Inside the catch block, the variables `$err:code`, `$err:description`, and `$err:value` provide details about the error.

### Custom Errors

You can raise your own errors with `error()` and catch them by name:

```xquery
declare namespace app="http://exist-db.org/myapp";

declare variable $app:ERROR := xs:QName("app:error");

try {
    error($app:ERROR, "Ooops", "any data")
} catch app:error {
    <error>Caught error {$err:code}: {$err:description}. Data: {$err:value}.</error>
}
```

## Group By

The `group by` clause in FLWOR expressions partitions results into groups.

### Odd and Even

```xquery
for $n in 1 to 10
group by $mod := $n mod 2
return
    if ($mod = 0) then
        <even>{$n}</even>
    else
        <odd>{$n}</odd>
```

After grouping, `$n` contains *all* the values that share the same group key — so each `<even>` or `<odd>` element contains a sequence of numbers.

### Grouping Search Results

Group full-text search results by speaker:

<!-- context: data/shakespeare -->
```xquery
let $query := "king"
for $speechBySpeaker in //SPEECH[ft:query(., $query)]
group by $speaker := $speechBySpeaker/SPEAKER
order by $speaker
return
    <speaker name="{$speaker}">
        {$speechBySpeaker}
    </speaker>
```

This finds all speeches mentioning "king" and groups them by who said them, making it easy to see which characters discuss royalty most.
