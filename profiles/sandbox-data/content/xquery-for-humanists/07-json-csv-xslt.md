# JSON, CSV, and XSLT

XQuery 3.1 can work with data beyond XML — including JSON, CSV, and XSLT stylesheets.

## Parsing JSON

Use `fn:parse-json()` to convert a JSON string into XQuery maps and arrays:

```xquery
let $json-string :=
'{
    "University of Central Florida": 63016,
    "Texas A&M University": 58515,
    "Ohio State University": 55508,
    "Vanderbilt University": 12605
}'
let $parsed := fn:parse-json($json-string)
return
    $parsed?("Vanderbilt University")
```

JSON objects become maps, JSON arrays become arrays.

## Liberal JSON Parsing

Strict JSON requires quoted keys. The `liberal` option relaxes this:

```xquery
'{ answer : 42 }' => fn:parse-json(map {"liberal": true()})
```

## Building JSON from XQuery

Construct maps and arrays in XQuery, then serialize as JSON:

```xquery
declare function local:milliseconds-since-epoch($now as xs:dateTime) as xs:integer {
    let $epoch := xs:dateTime("1970-01-01T00:00:00Z")
    let $duration := $now - $epoch
    return
        ($duration div xs:dayTimeDuration("PT0.001S")) cast as xs:integer
};

let $date := fn:format-date(fn:current-date(), "[M01]-[D01]-[Y0001]")
let $time := fn:format-time(fn:current-time(), "[h01]:[m01]:[s01] [PN]")
let $epoch := local:milliseconds-since-epoch(fn:current-dateTime())
return
    map {
        "time": $time,
        "date": $date,
        "milliseconds_since_epoch": $epoch
    }
```

## JSON-to-XML and Back

XPath 3.1 defines an XML representation of JSON. Convert between them with `fn:json-to-xml()` and `fn:xml-to-json()`:

```xquery
let $json := '{
    "time": "04:07:53 PM",
    "date": "08-30-2016",
    "milliseconds_since_epoch": 1472591273170
}'
return
    fn:json-to-xml($json)
```

And back to JSON:

```xquery
let $xml :=
    <map xmlns="http://www.w3.org/2005/xpath-functions">
        <string key="time">04:07:53 PM</string>
        <string key="date">08-30-2016</string>
        <number key="milliseconds_since_epoch">1472591273170</number>
    </map>
return
    fn:xml-to-json($xml, map {"indent": true()})
```

## Reading CSV Files

XQuery doesn't have a built-in CSV parser, but `fn:unparsed-text-lines()` reads a file as lines of text, and you can tokenize from there:

<!-- context: data -->
```xquery
fn:unparsed-text-lines("data/books.csv")
```

## Parsing CSV into XML

Split each line on commas and use the header row for element names:

<!-- context: data -->
```xquery
let $lines := fn:unparsed-text-lines("data/books.csv")
let $headers := fn:tokenize($lines[1], ",") ! fn:replace(., " ", "")
for $line in $lines[position() = 2 to last()]
let $columns := fn:tokenize($line, ",")
return
    element row {
        for $column at $count in $columns
        return
            element {$headers[$count]} {$column}
    }
```

The `! fn:replace(., " ", "")` removes spaces from header names to ensure they're valid XML element names.

## A Complete CSV Parser

Real CSV files may have quoted fields containing commas. This parser handles that using `fn:analyze-string()`:

<!-- context: data -->
```xquery
declare function local:parse-row($row as xs:string) as xs:string* {
    let $string-to-analyze := $row || ","
    let $quoted := '"[^"]*"'
    let $unquoted := '[^,]*'
    let $cell-regex := "(" || $quoted || "|" || $unquoted || "),"
    let $analysis := fn:analyze-string($string-to-analyze, $cell-regex)
    for $cell in $analysis//fn:group[@nr = "1"]
    return
        if (matches($cell, '^".+"$')) then
            replace($cell, '^"([^"]+)"$', '$1')
        else
            $cell/string()
};

declare function local:csv-to-xml($uri as xs:string) as element(csv) {
    let $lines := fn:unparsed-text-lines($uri)
    let $headers := local:parse-row(fn:head($lines)) ! replace(., " ", "_")
    return
        element csv {
            for $row in fn:tail($lines)
            let $cells := local:parse-row($row)
            return
                element row {
                    for $cell at $n in $cells
                    return
                        element {$headers[$n]} {$cell}
                }
        }
};

local:csv-to-xml("data/books.csv")
```

## XML to CSV

Convert XML data back to CSV using arrays:

<!-- context: data -->
```xquery
declare function local:rows-to-csv($rows as array(*)*) {
    let $cell-sep := ','
    let $row-sep := '&#10;'
    return
        string-join(
            for $row in $rows
            return string-join($row?*, $cell-sep),
            $row-sep
        )
};

let $books := fn:doc("data/books.xml")//row
let $headers := $books[1]/*/name() ! replace(., '_', ' ')
let $header-row := array {$headers}
let $body-rows :=
    for $book in $books
    return
        array {
            for $cell in $book/*
            return
                if (contains($cell, ',')) then '"' || $cell || '"'
                else $cell/string()
        }
return
    local:rows-to-csv(($header-row, $body-rows))
```
