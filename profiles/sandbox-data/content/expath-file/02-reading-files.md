# Reading Files

The EXPath File Module provides functions for reading text and binary content from the filesystem.

## Read Text

Read an entire file as a string. Newlines are normalized per spec (CR and CRLF become LF):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:create-dir($dir)
let $_ := exfile:write-text($dir || "greeting.txt", "Hello, World!")
return
    exfile:read-text($dir || "greeting.txt")
```

## Read with Encoding

Specify a character encoding for the file:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:write-text($dir || "utf8.txt", "Caf&#233; &#8212; Stra&#223;e &#8212; &#26481;&#20140;", "UTF-8")
return
    exfile:read-text($dir || "utf8.txt", "UTF-8")
```

## Read Text Lines

Read a file as a sequence of lines. Each line is a separate string in the result:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:write-text-lines($dir || "colors.txt", ("red", "green", "blue", "yellow"))
return
    exfile:read-text-lines($dir || "colors.txt")
```

Use the result with FLWOR expressions for line-by-line processing:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:write-text-lines($dir || "items.txt", ("apple,3", "banana,5", "cherry,12"))
return
    for $line at $pos in exfile:read-text-lines($dir || "items.txt")
    let $parts := tokenize($line, ",")
    return
        <item n="{$pos}" name="{$parts[1]}" qty="{$parts[2]}"/>
```

## Read Binary

Read a file as `xs:base64Binary`. Supports optional offset and length for partial reads:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $data := xs:base64Binary(xs:hexBinary("48656C6C6F")) (: "Hello" in hex :)
let $_ := exfile:write-binary($dir || "hello.bin", $data)
return
    xs:hexBinary(exfile:read-binary($dir || "hello.bin"))
```

Read a subset of bytes with offset and length:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $data := xs:base64Binary(xs:hexBinary("000102030405060708090A"))
let $_ := exfile:write-binary($dir || "bytes.bin", $data)
return (
    "Full:    " || xs:hexBinary(exfile:read-binary($dir || "bytes.bin")),
    "Offset 3: " || xs:hexBinary(exfile:read-binary($dir || "bytes.bin", 3)),
    "Off 3 Len 4: " || xs:hexBinary(exfile:read-binary($dir || "bytes.bin", 3, 4))
)
```
