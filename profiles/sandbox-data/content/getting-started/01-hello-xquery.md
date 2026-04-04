# Hello XQuery

XQuery is a powerful language for querying and transforming XML data. In this chapter, we'll start with the basics: simple expressions, querying documents, and searching collections.

## Hello World

The simplest XQuery expression returns a value directly. Here we construct an XML element with an embedded expression:

```xquery
let $msg := 'Hello XQuery'
return
  <results timestamp="{current-dateTime()}">
     <message>{$msg}</message>
  </results>
```

The curly braces `{}` inside XML mark *enclosed expressions* — XQuery code that gets evaluated and inserted into the output.

## Querying a Document

Use `doc()` to load an XML document from the database and navigate it with XPath:

<!-- context: data/shakespeare -->
```xquery
doc("data/shakespeare/hamlet.xml")/PLAY/TITLE
```

This retrieves the title element from Shakespeare's Hamlet.

## Querying a Collection

Use `collection()` to query across all documents in a database collection:

<!-- context: data/shakespeare -->
```xquery
collection("data/shakespeare")/PLAY/TITLE
```

This returns the titles of all Shakespeare plays stored in the collection.

## Finding Elements with contains()

You can use XPath predicates to filter results. Here we find all speeches containing a specific word:

<!-- context: data/shakespeare -->
```xquery
collection("data/shakespeare")//SPEECH[contains(LINE, "hurlyburly")]
```

The `//` axis searches all descendants, and the predicate `[contains(LINE, "hurlyburly")]` filters to only speeches with a matching line.

## Distinct Values

The `distinct-values()` function removes duplicates from a sequence. Here we list all speakers in a specific scene:

<!-- context: data/shakespeare -->
```xquery
distinct-values(
    doc("data/shakespeare/hamlet.xml")//ACT[1]/SCENE[2]//SPEAKER
)
```

This returns each speaker name exactly once, even if they appear in multiple speeches within the scene.
