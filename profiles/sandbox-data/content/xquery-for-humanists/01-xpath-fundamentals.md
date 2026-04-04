# XPath Fundamentals

XPath is the language for navigating XML documents. Every XQuery expression builds on XPath, so understanding it is essential. In this chapter, we'll explore XPath using a simple book record.

## Navigating with Axes

XPath uses *axes* to describe directions of navigation through the XML tree. The most common is `child::`, which selects direct children of the current node:

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

/child::book/child::title
```

This returns `<title>Primo Levi: The Matter of a Life</title>`.

## Abbreviated Syntax

In practice, XPath offers a shorter syntax. The `child::` axis is the default (you can omit it), and `//` is shorthand for `descendant-or-self::`:

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

(
    /book/title,             (: same as /child::book/child::title :)
    //press,                 (: finds press anywhere in the tree :)
    /book/identifier/@type   (: @ is shorthand for attribute:: :)
)
```

## Predicates

Square brackets filter results. You can filter by element content, attribute values, or position:

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

(
    /book/identifier[@type = "ISBN-13"],
    /book[date/@year/xs:integer(.) gt 2012],
    /book/identifier[fn:position() = (1 to 2)]
)
```

Note the use of `xs:integer(.)` to cast the year attribute to a number for numeric comparison — without it, `"2013" gt "2012"` would be a string comparison.

## String Functions

XPath includes a rich set of string functions:

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

(
    fn:concat(/book/title, " by ", /book/author),
    /book/publisher/press[fn:contains(., "University Press")]/text(),
    /book/identifier/fn:replace(., "-", ""),
    /book/identifier/fn:string-length(fn:replace(., "-", ""))
)
```

The last expression chains two functions: first remove dashes, then count the characters. The ISBN-13 without dashes is 13 characters long.

## Navigating Between Siblings

XPath axes let you move sideways and upward in the tree, not just downward:

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

(: Starting from the press element, navigate up to publisher,
   then back to the preceding title sibling :)
//press[. = "Yale University Press"]/parent::publisher/preceding-sibling::title/text()
```

This query finds the press element, goes up to its parent (`publisher`), then moves backward to the `title` sibling — returning "Primo Levi: The Matter of a Life".

## Union Expressions

The `|` operator (or its synonym, `union`) combines results from multiple paths:

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

(: Select either author or creator — useful when element names vary :)
/book/(author|creator)
```
