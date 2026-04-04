# Parsing CSV

XQuery can parse CSV (comma-separated values) text into XML by combining `tokenize()` with FLWOR expressions.

## Basic Parsing

Split lines on newlines, then split each line on commas:

```xquery
let $csv :=
'John, Smith, x123
Peg, Jones, x456
Sue, Adams, x789
Dan, McCoy, x321'

let $lines := tokenize($csv, '\n')
return
    <results>{
        for $line in $lines
        let $fields := tokenize($line, '\s*,\s*')
        return
            <row>{
                for $field in $fields
                return <field>{$field}</field>
            }</row>
    }</results>
```

The regex `\s*,\s*` trims whitespace around commas.

## Using Headers as Element Names

Treat the first row as column headers and use them as XML element names:

```xquery
let $csv :=
'name,faculty
alice,anthropology
bob,biology
carol,chemistry
dave,divinity'

let $lines := tokenize($csv, '\n')
let $head := tokenize($lines[1], ',')
let $body := remove($lines, 1)
return
    <people>{
        for $line in $body
        let $fields := tokenize($line, ',')
        return
            <person>{
                for $key at $pos in $head
                let $value := $fields[$pos]
                return
                    element {$key} {$value}
            }</person>
    }</people>
```

The `element {$key} {$value}` syntax is a *computed element constructor* — the element name comes from the variable `$key`.

## Configurable Parser

Make the parser flexible with a configuration element:

```xquery
let $config :=
    <config>
        <field-separator>:</field-separator>
        <root-element>People</root-element>
        <row-element>Person</row-element>
    </config>

let $csv :=
'name:faculty:year
alice:anthropology:2020
bob:biology:2019
carol:chemistry:2021'

let $lines := tokenize($csv, '\n')
let $head := tokenize($lines[1], $config/field-separator)
let $body := remove($lines, 1)
return
    element {$config/root-element} {
        for $line in $body
        let $fields := tokenize($line, $config/field-separator)
        return
            element {$config/row-element} {
                for $key at $pos in $head
                let $value := $fields[$pos]
                return
                    element {$key} {$value}
            }
    }
```

This parser works with any delimiter (commas, colons, tabs) and produces any root/row element names you configure.

## Generating CSV from XML

The reverse operation — convert XML to CSV:

```xquery
let $data :=
    <people>
        <person><name>Alice</name><dept>Anthropology</dept><ext>x123</ext></person>
        <person><name>Bob</name><dept>Biology</dept><ext>x456</ext></person>
        <person><name>Carol</name><dept>Chemistry, Applied</dept><ext>x789</ext></person>
    </people>
let $nl := '&#10;'
let $headers := $data/person[1]/*/name()
let $header-row := string-join($headers, ',')
let $body-rows :=
    for $person in $data/person
    return
        string-join(
            for $field in $person/*
            return
                if (contains($field, ',')) then '"' || $field || '"'
                else string($field),
            ','
        )
return
    string-join(($header-row, $body-rows), $nl)
```

Note the quoting logic: fields containing commas are wrapped in double quotes.
