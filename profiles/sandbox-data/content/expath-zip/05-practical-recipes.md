# Practical Recipes

This chapter shows real-world patterns for working with ZIP archives in eXist-db applications.

## Recipe: CSV Import from ZIP

Many data providers deliver CSV files inside ZIP archives. Extract and parse them into XML:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $csv := zip:text-entry(xs:anyURI("data/sample.zip"), "data/cities.csv")
let $lines := tokenize($csv, '\n')[. ne '']
let $headers := tokenize($lines[1], ',')
return
    <cities>
    {
        for $line in subsequence($lines, 2)
        let $fields := tokenize($line, ',')
        return
            <city>
            {
                for $header at $i in $headers
                return
                    element {replace(lower-case(normalize-space($header)), '\s+', '-')} {
                        normalize-space($fields[$i])
                    }
            }
            </city>
    }
    </cities>
```

This generic pattern works with any CSV: it reads the headers from the first line and dynamically creates element names from them.

## Recipe: Archive Manifest Validation

Check that every file listed in a manifest actually exists in the archive:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $href := xs:anyURI("data/sample.zip")
let $manifest := zip:xml-entry($href, "manifest.xml")
let $entries := zip:entries($href)
let $actual-names := $entries//zip:entry/@name/string()
return
    <validation>
    {
        for $file in $manifest//file
        let $name := $file/@name/string()
        return
            <check file="{$name}"
                   exists="{$name = $actual-names}"
                   type="{$file/@type}"/>
    }
    </validation>
```

## Recipe: Cross-Archive Search

Search for a term across XML files in multiple archives:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $search-term := "Priscilla"
let $archives := ("data/sample.zip", "data/books.zip")
return
    <search term="{$search-term}">
    {
        for $archive in $archives
        let $href := xs:anyURI($archive)
        let $entries := zip:entries($href)
        for $entry in $entries//zip:entry
        let $name := $entry/@name/string()
        where ends-with($name, '.xml')
        let $doc := zip:xml-entry($href, $name)
        where contains(serialize($doc), $search-term)
        return
            <match archive="{$archive}" entry="{$name}">
            {
                for $node in $doc//*[contains(., $search-term)]
                return
                    <context element="{local-name($node)}">{
                        substring(normalize-space($node), 1, 100)
                    }</context>
            }
            </match>
    }
    </search>
```

## Recipe: Archive Size Report

Generate a report showing the largest files across multiple archives:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $archives := ("data/sample.zip", "data/books.zip")
let $all-entries :=
    for $archive in $archives
    let $entries := zip:entries(xs:anyURI($archive))
    for $entry in $entries//zip:entry[@size]
    return
        map {
            "archive": $archive,
            "name": $entry/@name/string(),
            "size": xs:integer($entry/@size),
            "compressed": xs:integer($entry/@compressed-size)
        }
return
    <size-report>
        <total-archives>{count($archives)}</total-archives>
        <total-files>{count($all-entries)}</total-files>
        <largest-files>{
            for $entry in $all-entries
            order by $entry?size descending
            return
                <file archive="{$entry?archive}"
                      name="{$entry?name}"
                      size="{$entry?size}"
                      compressed="{$entry?compressed}"/>
        }</largest-files>
    </size-report>
```

## Recipe: Generate a Backup Archive

Package a database collection as a ZIP archive:

```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $collection := "/db/apps/sandbox"
let $resources := xmldb:get-child-resources($collection)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="backup-manifest.xml" method="xml">
            <backup collection="{$collection}" timestamp="{current-dateTime()}">
            {
                for $r in $resources
                return <resource name="{$r}" type="{xmldb:get-mime-type(xs:anyURI($collection || '/' || $r))}"/>
            }
            </backup>
        </zip:entry>
    </zip:file>
return
    <result>
        <resources-found>{count($resources)}</resources-found>
        <archive-created>{zip:zip-file($zip-desc) instance of xs:base64Binary}</archive-created>
    </result>
```

This pattern creates a manifest of the collection contents. A full backup implementation would also include the resource contents as additional `zip:entry` elements.

## Recipe: Merge Two Archives

Combine entries from two archives into a new one:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Read entries from both archives :)
let $sample-entries := zip:entries(xs:anyURI("data/sample.zip"))
let $books-entries := zip:entries(xs:anyURI("data/books.zip"))

(: Build a new archive with selected entries from each :)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="merged-manifest.xml" method="xml">
            <merged-archive created="{current-dateTime()}">
                <source archive="sample.zip">
                {
                    for $e in $sample-entries//zip:entry
                    return <entry name="{$e/@name}"/>
                }
                </source>
                <source archive="books.zip">
                {
                    for $e in $books-entries//zip:entry
                    return <entry name="{$e/@name}"/>
                }
                </source>
            </merged-archive>
        </zip:entry>
        <zip:dir name="sample">
            <zip:entry name="countries.xml" method="xml">
            { zip:xml-entry(xs:anyURI("data/sample.zip"), "data/countries.xml")/* }
            </zip:entry>
        </zip:dir>
        <zip:dir name="books">
            <zip:entry name="catalog.xml" method="xml">
            { zip:xml-entry(xs:anyURI("data/books.zip"), "catalog.xml")/* }
            </zip:entry>
        </zip:dir>
    </zip:file>
let $merged := zip:zip-file($zip-desc)
return
    <result>
        <created>{$merged instance of xs:base64Binary}</created>
        <base64-length>{string-length(string($merged))}</base64-length>
    </result>
```
