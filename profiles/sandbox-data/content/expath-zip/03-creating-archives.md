# Creating Archives

The `zip:zip-file` function creates a new ZIP archive from an XML description. You describe the archive structure using `zip:file`, `zip:dir`, and `zip:entry` elements, and the function returns the archive as an `xs:base64Binary` value.

## Creating a Simple Archive

The simplest case: a ZIP with a single text file containing inline content:

```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="hello.txt" method="text">Hello from XQuery!</zip:entry>
    </zip:file>
return
    zip:zip-file($zip-desc) instance of xs:base64Binary
```

The `method` attribute tells the ZIP module how to serialize the content: `text` for plain text, `xml` for XML serialization.

## Archive with Multiple Files

Create an archive with both text and XML entries:

```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="greeting.txt" method="text">Welcome to the EXPath ZIP module!</zip:entry>
        <zip:entry name="data.xml" method="xml">
            <catalog>
                <item id="1">First item</item>
                <item id="2">Second item</item>
            </catalog>
        </zip:entry>
    </zip:file>
let $binary := zip:zip-file($zip-desc)
return
    <result>
        <is-binary>{$binary instance of xs:base64Binary}</is-binary>
        <base64-length>{string-length(string($binary))}</base64-length>
    </result>
```

## Creating Archives with Directories

Use `zip:dir` elements to organize entries into directories:

```xquery
import module namespace zip = "http://expath.org/ns/zip";

let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="README.txt" method="text">Project documentation archive</zip:entry>
        <zip:dir name="src">
            <zip:entry name="main.xq" method="text">
xquery version "3.1";
&lt;hello&gt;world&lt;/hello&gt;
            </zip:entry>
            <zip:entry name="utils.xq" method="text">
module namespace u = "http://example.com/utils";
declare function u:greet($name as xs:string) {{ &lt;greeting&gt;Hello, {{$name}}&lt;/greeting&gt; }};
            </zip:entry>
        </zip:dir>
        <zip:dir name="docs">
            <zip:entry name="api.xml" method="xml">
                <api version="1.0">
                    <endpoint path="/greet" method="GET"/>
                </api>
            </zip:entry>
        </zip:dir>
    </zip:file>
return
    zip:zip-file($zip-desc) instance of xs:base64Binary
```

## Round-Trip: Create and Read Back

Create a ZIP, store it in the database, then read entries back to verify the content:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Step 1: Create a ZIP with data :)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="config.xml" method="xml">
            <config>
                <setting name="debug" value="false"/>
                <setting name="timeout" value="30"/>
            </config>
        </zip:entry>
        <zip:entry name="notes.txt" method="text">Created by XQuery at {current-dateTime()}</zip:entry>
    </zip:file>
let $binary := zip:zip-file($zip-desc)

(: Step 2: Store in the database :)
let $stored := xmldb:store("data", "roundtrip.zip", $binary, "application/zip")

(: Step 3: Read back and verify :)
let $config := zip:xml-entry(xs:anyURI("data/roundtrip.zip"), "config.xml")
let $notes := zip:text-entry(xs:anyURI("data/roundtrip.zip"), "notes.txt")
return
    <verification>
        <config-settings>{count($config//setting)}</config-settings>
        <notes-preview>{substring($notes, 1, 50)}</notes-preview>
    </verification>
```

## Generating an Archive from Query Results

A powerful pattern: query the database and package the results as a downloadable ZIP:

<!-- context: data -->
```xquery
import module namespace zip = "http://expath.org/ns/zip";

(: Query data from an existing archive :)
let $countries := zip:xml-entry(xs:anyURI("data/sample.zip"), "data/countries.xml")

(: Build a new ZIP with transformed data :)
let $zip-desc :=
    <zip:file xmlns:zip="http://expath.org/ns/zip">
        <zip:entry name="report.xml" method="xml">
            <report generated="{current-dateTime()}">
            {
                for $c in $countries//country
                order by xs:integer($c/@population) descending
                return
                    <country rank="{position()}"
                             name="{$c/@name}"
                             population="{format-number(xs:integer($c/@population), '#,###')}"/>
            }
            </report>
        </zip:entry>
        <zip:entry name="summary.txt" method="text">Population Report
Generated: {current-dateTime()}
Countries: {count($countries//country)}
Total population: {format-number(sum($countries//country/@population ! xs:integer(.)), '#,###')}</zip:entry>
    </zip:file>
return
    zip:zip-file($zip-desc) instance of xs:base64Binary
```
