# Working with Data

This chapter covers practical recipes for generating HTML output, building tables, creating lists, and working with dates.

## Generating HTML Tables

Display XML data in an HTML table with alternating row colors:

```xquery
let $terms :=
    <terms>
        <term>
            <term-name>Object Class</term-name>
            <definition>A set of ideas, abstractions, or things in the real world</definition>
        </term>
        <term>
            <term-name>Organization</term-name>
            <definition>A unit consisting of people and processes</definition>
        </term>
        <term>
            <term-name>Data Element</term-name>
            <definition>A unit of data for which the definition and value domain are specified</definition>
        </term>
        <term>
            <term-name>Value Domain</term-name>
            <definition>A set of permissible values for a data element</definition>
        </term>
    </terms>
return
    <table border="1">
        <thead>
            <tr><th>Term</th><th>Definition</th></tr>
        </thead>
        <tbody>{
            for $term at $count in $terms/term
            order by upper-case($term/term-name)
            return
                <tr>{
                    if ($count mod 2) then attribute class {'odd'}
                    else attribute class {'even'}
                }
                    <td>{$term/term-name/text()}</td>
                    <td>{$term/definition/text()}</td>
                </tr>
        }</tbody>
    </table>
```

The `attribute class {'odd'}` syntax dynamically adds a CSS class to each row. Using `upper-case()` in the `order by` ensures case-insensitive sorting.

## Creating Comma-Separated Lists

Use `string-join()` to format sequences as delimited strings:

```xquery
let $tags :=
    <tags>
        <tag>XML</tag>
        <tag>XQuery</tag>
        <tag>XPath</tag>
        <tag>XSLT</tag>
    </tags>
return (
    string-join($tags/tag, ', '),
    string-join($tags/tag, ' | '),
    string-join($tags/tag)
)
```

## FLWOR with Ranges and Counters

Use `to` for numeric ranges and `at` for positional counters:

```xquery
<items>{
    let $items := ("apples", "pears", "oranges", "bananas", "grapes")
    for $item at $count in $items
    return
        <item id="{$count}">{$item}</item>
}</items>
```

## Quantified Expressions

Test whether any or all items in a sequence satisfy a condition:

```xquery
let $books :=
    <books>
        <book><title>The Cat in the Hat</title></book>
        <book><title>War and Peace</title></book>
        <book><title>Cat's Cradle</title></book>
    </books>
return (
    (: Does any book mention "Cat"? :)
    some $book in $books/book
    satisfies contains(lower-case($book/title), 'cat'),

    (: Do all books mention "Cat"? :)
    every $book in $books/book
    satisfies contains(lower-case($book/title), 'cat')
)
```

## Working with Dates

XQuery has built-in date and time functions:

```xquery
let $today := current-date()
let $now := current-dateTime()
let $one-week-ago := $today - xs:dayTimeDuration('P7D')
let $one-month-ahead := $today + xs:yearMonthDuration('P1M')
return
    map {
        "today": string($today),
        "now": string($now),
        "one-week-ago": string($one-week-ago),
        "one-month-ahead": string($one-month-ahead),
        "day-of-week": format-date($today, "[FNn]"),
        "formatted": format-date($today, "[MNn] [D], [Y]")
    }
```
