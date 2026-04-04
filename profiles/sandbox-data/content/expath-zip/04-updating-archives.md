# Updating Archives

The `zip:update-entries` function takes an existing ZIP archive, applies modifications (replacing or adding entries), and writes the result to a new location. The original archive is not modified.

## Replacing an Entry

Replace a text file in an existing archive with new content:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Check original content :)
let $original := zip:text-entry(xs:anyURI("data/books.zip"), "notes.txt")

(: Replace the notes entry :)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip" href="{request:get-uri()/../data/books.zip}">
        <zip:entry name="notes.txt" method="text">Updated notes: These books cover XML technologies including XQuery, XSLT, and XPath. Last updated: {current-dateTime()}</zip:entry>
    </zip:file>
let $_ := zip:update-entries($zip-desc, xs:anyURI("data/books-updated.zip"))

(: Verify the change :)
let $updated := zip:text-entry(xs:anyURI("data/books-updated.zip"), "notes.txt")
return
    <result>
        <original>{$original}</original>
        <updated>{$updated}</updated>
    </result>
```

The `href` attribute on `zip:file` points to the source archive. Entries listed in the descriptor replace matching entries in the source; all other entries are copied unchanged.

## Adding a New Entry

Add a new file to an existing archive without touching the existing entries:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip" href="{request:get-uri()/../data/books.zip}">
        <zip:entry name="index.xml" method="xml">
            <index created="{current-dateTime()}">
                <entry file="catalog.xml" type="XML" description="Book catalog"/>
                <entry file="notes.txt" type="text" description="Reading notes"/>
            </index>
        </zip:entry>
    </zip:file>
let $_ := zip:update-entries($zip-desc, xs:anyURI("data/books-with-index.zip"))

(: Verify: the new entry exists alongside the originals :)
let $entries := zip:entries(xs:anyURI("data/books-with-index.zip"))
return
    <result>
        <entry-count>{count($entries//zip:entry)}</entry-count>
        <entry-names>{
            string-join($entries//zip:entry/@name, ', ')
        }</entry-names>
    </result>
```

## Replacing XML Content

Replace an XML entry with transformed data:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Read the original catalog :)
let $catalog := zip:xml-entry(xs:anyURI("data/books.zip"), "catalog.xml")

(: Create an updated catalog with a new book added :)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip" href="{request:get-uri()/../data/books.zip}">
        <zip:entry name="catalog.xml" method="xml">
            <catalog>
            {$catalog//book}
                <book isbn="978-1-4842-6735-0">
                    <title>eXist: A NoSQL Document Database and Application Platform</title>
                    <author>Erik Siegel</author>
                    <author>Adam Retter</author>
                    <publisher>O'Reilly Media</publisher>
                    <year>2014</year>
                </book>
            </catalog>
        </zip:entry>
    </zip:file>
let $_ := zip:update-entries($zip-desc, xs:anyURI("data/books-expanded.zip"))

(: Verify :)
let $new-catalog := zip:xml-entry(xs:anyURI("data/books-expanded.zip"), "catalog.xml")
return
    <result>
        <original-count>{count($catalog//book)}</original-count>
        <new-count>{count($new-catalog//book)}</new-count>
        <new-titles>{
            for $book in $new-catalog//book
            return <title>{$book/title/string()}</title>
        }</new-titles>
    </result>
```
