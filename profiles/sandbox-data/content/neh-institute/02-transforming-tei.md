# Transforming TEI to HTML

The most common task with TEI documents is transforming them into HTML for web display. XQuery's `typeswitch` expression is ideal for this — it dispatches on element types and recursively processes the document tree, much like XSLT's template matching.

## The Typeswitch Pattern

A TEI-to-HTML transformation has three parts:

1. A **dispatch** function that matches element types
2. **Handler functions** for each TEI element
3. A **passthru** function that recurses into unmatched elements

Here's a minimal example:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:dispatch($node as node()) as item()* {
    typeswitch($node)
        case text() return $node
        case element(tei:p) return <p>{local:passthru($node)}</p>
        case element(tei:emph) return <em>{local:passthru($node)}</em>
        case element(tei:title) return <cite>{local:passthru($node)}</cite>
        default return local:passthru($node)
};

declare function local:passthru($node as node()) as item()* {
    for $child in $node/node()
    return local:dispatch($child)
};

let $tei :=
    <body xmlns="http://www.tei-c.org/ns/1.0">
        <p>He read <title>War and Peace</title> with <emph>great</emph> interest.</p>
    </body>
return
    <div>{local:passthru($tei)}</div>
```

The key insight: `local:passthru` calls `local:dispatch` on each child, and each handler calls `local:passthru` on its own children. This mutual recursion walks the entire tree.

## A Complete TEI Transformer

This transformer handles the most common TEI elements found in prose documents — letters, essays, and narrative texts:

```xquery
declare default element namespace "http://www.w3.org/1999/xhtml";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:dispatch($node as node()) as item()* {
    typeswitch($node)
        case text() return $node
        case element(tei:body) return
            <section id="body">{local:passthru($node)}</section>
        case element(tei:div) return
            <div>{local:passthru($node)}</div>
        case element(tei:head) return
            <h2>{local:passthru($node)}</h2>
        case element(tei:p) return
            <p>{local:passthru($node)}</p>
        case element(tei:ab) return
            <p>{local:passthru($node)}</p>
        case element(tei:opener) return
            <p class="opener">{local:passthru($node)}</p>
        case element(tei:closer) return
            <p class="closer">{local:passthru($node)}</p>
        case element(tei:salute) return
            <span class="salute">{local:passthru($node)}</span>
        case element(tei:signed) return
            <span class="signed">{local:passthru($node)}</span>
        case element(tei:dateline) return
            <span class="dateline">{local:passthru($node)}</span>
        case element(tei:emph) return
            <em>{local:passthru($node)}</em>
        case element(tei:title) return
            <cite>{local:passthru($node)}</cite>
        case element(tei:persName) return
            <span class="persName">{local:passthru($node)}</span>
        case element(tei:placeName) return
            <span class="placeName">{local:passthru($node)}</span>
        case element(tei:name) return
            <span class="name">{local:passthru($node)}</span>
        case element(tei:date) return
            <time datetime="{$node/@when}">{local:passthru($node)}</time>
        case element(tei:quote) return
            <q>{local:passthru($node)}</q>
        case element(tei:q) return
            <q>{local:passthru($node)}</q>
        case element(tei:cit) return
            <blockquote>{local:passthru($node)}</blockquote>
        case element(tei:bibl) return
            <cite>{local:passthru($node)}</cite>
        case element(tei:ref) return
            <a href="{$node/@target}">{local:passthru($node)}</a>
        case element(tei:note) return
            <span class="note">[{local:passthru($node)}]</span>
        case element(tei:sic) return
            <span class="sic" title="sic">{local:passthru($node)}</span>
        case element(tei:soCalled) return
            <span class="soCalled">"{local:passthru($node)}"</span>
        case element(tei:lb) return <br/>
        case element(tei:pb) return
            <hr class="page-break" title="page {$node/@n}"/>
        default return local:passthru($node)
};

declare function local:passthru($node as node()) as item()* {
    for $child in $node/node()
    return local:dispatch($child)
};

let $letter :=
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
        <text>
            <body>
                <opener>
                    <dateline>
                        <placeName>Nashville</placeName>,
                        <date when="1862-03-15">March 15, 1862</date>
                    </dateline>
                    <salute>Dear <persName>Governor Johnson</persName>,</salute>
                </opener>
                <p>I write to inform you that <persName>General Grant</persName>
                    has arrived at <placeName>Fort Donelson</placeName>.
                    The situation is, as they say, <soCalled>fluid</soCalled>.</p>
                <p>I quote from his dispatch: <cit><quote>We have taken the
                    fort.</quote> <bibl>Grant to Halleck, Feb 16</bibl></cit></p>
                <p>For further details, see <ref target="#appendix">the appendix</ref>.</p>
                <closer>
                    <salute>Your obedient servant,</salute>
                    <lb/>
                    <signed><persName>James Smith</persName></signed>
                </closer>
            </body>
        </text>
    </TEI>
return
    <html>
        <body>{local:dispatch($letter//tei:body)}</body>
    </html>
```

## Extending the Transformer

Adding support for a new element is straightforward — add a `case` to the dispatch function and write a handler. Here we add support for TEI `<lg>` (line group) and `<l>` (line) elements for poetry:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare function local:dispatch($node as node()) as item()* {
    typeswitch($node)
        case text() return $node
        case element(tei:body) return
            <div>{local:passthru($node)}</div>
        case element(tei:head) return
            <h2>{local:passthru($node)}</h2>
        case element(tei:lg) return
            <div class="stanza">{local:passthru($node)}</div>
        case element(tei:l) return
            (local:passthru($node),
             if ($node/following-sibling::tei:l) then <br/> else ())
        case element(tei:p) return
            <p>{local:passthru($node)}</p>
        case element(tei:emph) return
            <em>{local:passthru($node)}</em>
        case element(tei:persName) return
            <span class="person">{local:passthru($node)}</span>
        default return local:passthru($node)
};

declare function local:passthru($node as node()) as item()* {
    for $child in $node/node()
    return local:dispatch($child)
};

let $text :=
    <text xmlns="http://www.tei-c.org/ns/1.0">
        <body>
            <head>The Best Thing in the World</head>
            <p>By <persName>Elizabeth Barrett Browning</persName></p>
            <lg>
                <l>What's the best thing in the world?</l>
                <l>June-rose, by May-dew impearled;</l>
                <l>Sweet south-wind, that means no rain;</l>
                <l>Truth, not cruel to a friend;</l>
            </lg>
            <lg>
                <l>Pleasure, not in haste to end;</l>
                <l>Beauty, not self-decked and curled</l>
                <l>Till its pride is over-plain;</l>
                <l>Light, that never makes you wink;</l>
            </lg>
            <lg>
                <l>Memory, that gives no pain;</l>
                <l>Love, when, so, you're loved again.</l>
                <l>What's the best thing in the world?</l>
                <l>—Something out of it, I think.</l>
            </lg>
        </body>
    </text>
return
    <div>{local:passthru($text)}</div>
```

Each line gets a `<br/>` after it, except the last line in each stanza. The pattern of checking `following-sibling` is a common technique for handling inter-element separators.

## Design Considerations

When building a TEI transformer, keep these principles in mind:

- **Start with `passthru` as the default.** Unknown elements pass through silently — you add handlers as you encounter new element types in your corpus.
- **Context matters.** A `<title>` in a `<teiHeader>` should render differently than one in the body. Use the parent axis to distinguish: `if ($node/parent::tei:titleStmt) then <h1>... else <cite>...`.
- **Use CSS classes liberally.** Map TEI semantics to `class` attributes (`class="persName"`, `class="placeName"`) so styling can be controlled separately from structure.
- **Handle empty elements.** `<lb/>` and `<pb/>` have no children — their handlers should return an element directly without calling `passthru`.
