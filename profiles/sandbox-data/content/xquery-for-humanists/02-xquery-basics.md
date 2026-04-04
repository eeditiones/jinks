# XQuery Basics

XQuery builds on XPath by adding variables, iteration, sorting, grouping, and conditionals through FLWOR expressions (For, Let, Where, Order by, Return).

## Let and For

The `let` clause binds a value to a variable. The `for` clause iterates over a sequence:

```xquery
let $isbn := "978-0300137231"
let $isbn-without-dash := fn:replace($isbn, "-", "")
return
    fn:string-length($isbn-without-dash)
```

## Iterating Over Elements

Use `for` to process each item in a sequence:

```xquery
declare context item := document {
<book>
    <title>Primo Levi: The Matter of a Life</title>
    <author>Berel Lang</author>
    <date year="2013">November 26, 2013</date>
    <publisher>
        <city>New Haven</city>
        <press>Yale University Press</press>
    </publisher>
    <identifier type="ISBN-10">0300137230</identifier>
    <identifier type="ISBN-13">978-0300137231</identifier>
</book>
};

for $isbn in ./book/identifier
return
    fn:concat(fn:string($isbn/@type), ": ", $isbn/text())
```

## Where Clause

The `where` clause filters items, like a SQL WHERE:

```xquery
declare context item := document {
<book>
    <title>Primo Levi: The Matter of a Life</title>
    <author>Berel Lang</author>
    <date year="2013">November 26, 2013</date>
    <publisher>
        <city>New Haven</city>
        <press>Yale University Press</press>
    </publisher>
    <identifier type="ISBN-10">0300137230</identifier>
    <identifier type="ISBN-13">978-0300137231</identifier>
    <identifier type="OCLC">840803708</identifier>
</book>
};

for $identifier in ./book/identifier
where $identifier/@type = ("ISBN-10", "ISBN-13")
return
    $identifier/text()
```

This filters out the OCLC identifier, returning only the ISBN values.

## Order By

Sort results with `order by`. You can sort by multiple keys and in descending order:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $book in ./list/book
order by $book/@date descending, $book/text()
return
    $book
```

When multiple books share the same date, the second key (title text) breaks the tie alphabetically.

## Positional Variable

The `at` keyword captures each item's position in the input sequence:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $book at $n in ./list/book
return
    fn:concat($n, ". ", $book/text())
```

Note: `at` captures the *original* position before sorting. If you add `order by`, the numbers reflect document order, not the sorted order.

## Group By

The `group by` clause partitions results into groups sharing a common key:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $book in ./list/book
group by $date := $book/@date
return
    <list published="{$date}">
        {$book}
    </list>
```

After grouping, `$book` contains *all* books sharing that date — not just one.

## Count Clause

The `count` clause provides a counter variable. Its position relative to `order by` matters — placed *after* `order by`, it numbers the sorted results:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $book in ./list/book
order by $book/text()
count $n
return
    fn:concat($n, ". ", $book/text())
```

Move `count` *before* `order by`, and `$n` captures the original document position instead:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $book in ./list/book
count $n
order by $book/text()
return
    fn:concat($n, ". ", $book/text())
```

## Node Identity

XQuery distinguishes between nodes that look identical and nodes that are the same object in memory:

```xquery
let $title := <title>se questo è un uomo</title>
let $titolo := <title>se questo è un uomo</title>
let $titel := $title
return (
    $title is $titolo,  (: false — different nodes with same content :)
    $title is $titel    (: true — same node, assigned to another variable :)
)
```

## Conditional Expressions

Use `if`/`then`/`else` for branching logic:

```xquery
declare context item := document {
<list>
    <book date="2015">Interdisciplining Digital Humanities</book>
    <book date="2013">Hacking the Academy</book>
    <book date="2016">New Companion to Digital Humanities</book>
    <book date="2013">Macroanalysis</book>
    <book date="2013">Emergence of the Digital Humanities</book>
    <book date="2014">Digital Critical Editions</book>
    <book date="2015">Digital Humanities</book>
</list>
};

for $title in ./list/book/text()
return
    if (fn:contains($title, "Digital")) then
        "A book about something digital"
    else if (fn:contains($title, "Humanities")) then
        "A book about the humanities"
    else
        "A book about something else"
```

In XQuery, `if`/`then`/`else` is an *expression* that returns a value — the `else` branch is always required.
