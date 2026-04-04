# Reading ZIP Entries

> **Prerequisites:** This book requires the [exist-zip](https://github.com/joewiz/exist-zip) XAR package. The new module adds `zip:zip-file`, `zip:update-entries`, 3-argument `zip:text-entry`, and entry metadata (`@size`, `@compressed-size`) beyond what the bundled expath extension provides. To use the full feature set, remove the old module from `conf.xml`:
>
> ```xml
> <!-- Remove this line from conf.xml -->
> <module uri="http://expath.org/ns/zip" class="org.expath.exist.ZipModule"/>
> ```
>
> Then install the XAR: `xst package install exist-zip-0.9.0-SNAPSHOT.xar`

The EXPath ZIP module provides four functions for extracting content from ZIP archives: `zip:text-entry`, `zip:xml-entry`, `zip:html-entry`, and `zip:binary-entry`. Each interprets the raw bytes differently depending on what kind of content you expect.

## Extracting Text

Use `zip:text-entry` to read a plain text file from an archive. The result is an `xs:string`:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

zip:text-entry(xs:anyURI("data/sample.zip"), "README.txt")
```

The first argument is the URI of the ZIP file (in the database or on the filesystem), and the second is the path of the entry within the archive.

## Extracting XML

Use `zip:xml-entry` when the entry contains well-formed XML. The result is a `document-node()` that you can query with XPath:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $doc := zip:xml-entry(xs:anyURI("data/books.zip"), "catalog.xml")
return
    $doc//book[author = "Priscilla Walmsley"]/title
```

Because the result is a parsed XML document, you get full XPath navigation for free.

## Querying XML Inside a ZIP

You can use the full power of FLWOR expressions on data extracted from a ZIP:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $countries := zip:xml-entry(xs:anyURI("data/sample.zip"), "data/countries.xml")
for $c in $countries//country
where xs:integer($c/@population) > 100000000
order by xs:integer($c/@population) descending
return
    <result>
        <name>{$c/@name/string()}</name>
        <population>{format-number(xs:integer($c/@population), '#,###')}</population>
    </result>
```

This extracts the countries XML from the archive, filters to those with over 100 million people, and formats the output.

## Extracting HTML

Use `zip:html-entry` for HTML content. The HTML is parsed and returned as a well-formed XML document node, so you can query it with XPath even if the original HTML wasn't perfectly well-formed:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $page := zip:html-entry(xs:anyURI("data/sample.zip"), "pages/index.html")
return
    <links>{
        for $a in $page//a
        return
            <link href="{$a/@href}">{$a/string()}</link>
    }</links>
```

## Extracting Binary Data

Use `zip:binary-entry` for binary content like images, PDFs, or other non-text files. The result is an `xs:base64Binary` value:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $readme := zip:binary-entry(xs:anyURI("data/sample.zip"), "README.txt")
return
    <result>
        <type>{$readme instance of xs:base64Binary}</type>
        <length>{string-length(string($readme))}</length>
    </result>
```

Even though `README.txt` is text, `zip:binary-entry` returns it as raw base64. This is useful when you need to store the content as-is without character decoding.

## Specifying Text Encoding

By default, `zip:text-entry` reads text as UTF-8. If the file uses a different encoding, pass it as a third argument:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Read the CSV file explicitly as UTF-8 :)
let $csv := zip:text-entry(xs:anyURI("data/sample.zip"), "data/cities.csv", "UTF-8")
return
    <lines>{
        for $line in tokenize($csv, '\n')[position() gt 1][. ne '']
        let $fields := tokenize($line, ',')
        return
            <city name="{$fields[1]}" country="{$fields[2]}" population="{$fields[3]}"/>
    }</lines>
```

This example also shows a common pattern: parsing CSV data extracted from a ZIP archive.
