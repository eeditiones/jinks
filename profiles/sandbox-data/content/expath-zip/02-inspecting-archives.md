# Inspecting Archives

Before extracting content, you often need to know what's inside a ZIP file. The `zip:entries` function returns a structured XML description of the archive's contents.

## Listing Entries

The `zip:entries` function returns a `zip:file` element describing every entry in the archive:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

zip:entries(xs:anyURI("data/sample.zip"))
```

The result is an XML document with `zip:entry` elements for files and `zip:dir` elements for directories, each with metadata attributes like `size`, `compressed-size`, `last-modified`, and `method`.

## Counting Entries

Use XPath on the result to answer questions about the archive's structure:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $entries := zip:entries(xs:anyURI("data/sample.zip"))
return
    <summary>
        <total-entries>{count($entries//zip:entry)}</total-entries>
        <directories>{count($entries//zip:dir)}</directories>
    </summary>
```

## Filtering by File Extension

Find all XML files in an archive:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $entries := zip:entries(xs:anyURI("data/sample.zip"))
for $entry in $entries//zip:entry
where ends-with($entry/@name, '.xml')
return
    <xml-file name="{$entry/@name}" size="{$entry/@size}"/>
```

## Compression Statistics

Calculate the total size and compression ratio of an archive:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $entries := zip:entries(xs:anyURI("data/sample.zip"))
let $files := $entries//zip:entry[@size]
let $total-size := sum($files/@size ! xs:integer(.))
let $total-compressed := sum($files/@compressed-size ! xs:integer(.))
return
    <compression-stats>
        <file-count>{count($files)}</file-count>
        <total-size>{$total-size}</total-size>
        <total-compressed>{$total-compressed}</total-compressed>
        <ratio>{
            if ($total-size > 0)
            then round((1 - $total-compressed div $total-size) * 100) || '%'
            else 'N/A'
        }</ratio>
    </compression-stats>
```

## Comparing Two Archives

Compare the entry names in two different ZIP files to find what's unique to each:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $a := zip:entries(xs:anyURI("data/sample.zip"))//zip:entry/@name/string()
let $b := zip:entries(xs:anyURI("data/books.zip"))//zip:entry/@name/string()
return
    <comparison>
        <only-in-sample>{
            for $name in $a
            where not($name = $b)
            return <entry>{$name}</entry>
        }</only-in-sample>
        <only-in-books>{
            for $name in $b
            where not($name = $a)
            return <entry>{$name}</entry>
        }</only-in-books>
        <in-both>{
            for $name in $a
            where $name = $b
            return <entry>{$name}</entry>
        }</in-both>
    </comparison>
```

## Building a Table of Contents

Combine `zip:entries` with `zip:text-entry` and `zip:xml-entry` to build a rich table of contents:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $href := xs:anyURI("data/sample.zip")
let $entries := zip:entries($href)
return
    <archive href="{$entries/@href}">
    {
        for $entry in $entries//zip:entry
        let $name := $entry/@name/string()
        let $ext := tokenize($name, '\.')[last()]
        return
            <file name="{$name}"
                  size="{$entry/@size}"
                  type="{
                      switch ($ext)
                          case 'xml' return 'XML'
                          case 'html' return 'HTML'
                          case 'csv' return 'CSV'
                          case 'txt' return 'Text'
                          default return 'Binary'
                  }"/>
    }
    </archive>
```
