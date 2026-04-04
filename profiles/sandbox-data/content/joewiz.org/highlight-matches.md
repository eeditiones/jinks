---
title: "XQuery's Missing Third Function: highlight-matches()"
author: Joe Wicentowski
date: 2013-07-06
source: https://joewiz.org/2013/07/06/xquerys-missing-third-function/
---

# XQuery's Missing Third Function

Everyone learning XQuery for text searching quickly learns two functions: `contains()` to check if a string contains a phrase, and `matches()` for regular expression matching. But there's a glaring gap: no standard way to *highlight* the matching text.

By combining `analyze-string()` with higher-order functions, we can write a general-purpose `highlight-matches()` function.

## The Problem

`contains()` and `matches()` return booleans — they tell you *whether* text matches, but not *where*:

```xquery
let $titles := (
    <title>The Art of Pickling</title>,
    <title>How to Tickle the Ivories</title>,
    <title>A History of Brick Making</title>
)
return
    $titles[matches(., '[PT]ickl[a-z]+')]
```

This returns the matching titles, but without any indication of which part matched.

## The Solution

The `analyze-string()` function breaks text into matching and non-matching segments. We can walk the XML tree recursively, applying `analyze-string()` to each text node and calling a user-supplied function on matches:

```xquery
declare namespace fn="http://www.w3.org/2005/xpath-functions";

declare function local:highlight-matches(
    $nodes as node()*,
    $pattern as xs:string,
    $highlight as function(xs:string) as item()*
) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element() return
                element {name($node)} {
                    $node/@*,
                    local:highlight-matches($node/node(), $pattern, $highlight)
                }
            case text() return
                let $normalized := replace($node, '\s+', ' ')
                for $segment in analyze-string($normalized, $pattern)/node()
                return
                    if ($segment instance of element(fn:match)) then
                        $highlight($segment/string())
                    else
                        $segment/string()
            case document-node() return
                document {
                    local:highlight-matches($node/node(), $pattern, $highlight)
                }
            default return $node
};

let $article :=
    <article>
        <h1>Introduction</h1>
        <p>Higher-order functions are probably the most notable addition
            to the XQuery language in version 3.0. While it may take some
            time to understand their full impact, higher-order functions
            certainly open a wide range of new possibilities, and are a
            key feature in all functional languages.</p>
        <p>As of April 2012, eXist-db completely supports higher-order
            functions, including inline functions, closures, and partial
            function application.</p>
    </article>

let $pattern := '[Ff]un[a-z]+'
let $highlight := function($word as xs:string) {
    <mark>{$word}</mark>
}
return
    local:highlight-matches($article, $pattern, $highlight)
```

The third parameter is the key — it's a *function* that you define. This means you can highlight however you want:

## Custom Highlighting

Use different highlighting strategies by passing different functions:

```xquery
declare namespace fn="http://www.w3.org/2005/xpath-functions";

declare function local:highlight-matches(
    $nodes as node()*,
    $pattern as xs:string,
    $highlight as function(xs:string) as item()*
) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element() return
                element {name($node)} {
                    $node/@*,
                    local:highlight-matches($node/node(), $pattern, $highlight)
                }
            case text() return
                for $segment in analyze-string(replace($node, '\s+', ' '), $pattern)/node()
                return
                    if ($segment instance of element(fn:match)) then
                        $highlight($segment/string())
                    else $segment/string()
            default return $node
};

let $text :=
    <p>The quick brown fox jumps over the lazy dog.
       The fox was very foxy indeed.</p>

return (
    (: Bold highlighting :)
    local:highlight-matches($text, 'fox[a-z]*',
        function($w) { <b>{$w}</b> }),

    (: TEI person tagging :)
    local:highlight-matches(
        <p>Lincoln met with Grant at the White House.</p>,
        '(Lincoln|Grant)',
        function($name) { <persName xmlns="http://www.tei-c.org/ns/1.0">{$name}</persName> }),

    (: Counting matches :)
    let $result := local:highlight-matches($text, 'fox[a-z]*',
        function($w) { <match>{$w}</match> })
    return
        <stats>
            <match-count>{count($result//match)}</match-count>
            <matches>{$result//match/string() => string-join(', ')}</matches>
        </stats>
)
```

The power of higher-order functions: one `highlight-matches()` implementation supports bolding, TEI tagging, and match counting — all by swapping the function parameter.
