# Writing Files

The EXPath File Module provides functions for writing text, binary, and serialized XML content to the filesystem. Write functions create the file if it doesn't exist, or overwrite it if it does.

## Write Text

Write a string to a file:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:create-dir($dir)
let $_ := exfile:write-text($dir || "output.txt", "Written by XQuery!")
return
    exfile:read-text($dir || "output.txt")
```

## Write Text Lines

Write a sequence of strings as lines, each terminated by the platform line separator:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $names := ("Alice", "Bob", "Charlie")
let $_ := exfile:write-text-lines($dir || "names.txt", $names)
return
    exfile:read-text-lines($dir || "names.txt")
```

## Append Text

Append to an existing file without overwriting:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $log := $dir || "log.txt"
let $_ := exfile:write-text($log, "")
let $_ := exfile:append-text($log, "[INFO] Started" || exfile:line-separator())
let $_ := exfile:append-text($log, "[INFO] Processing" || exfile:line-separator())
let $_ := exfile:append-text($log, "[INFO] Finished" || exfile:line-separator())
return
    exfile:read-text-lines($log)
```

## Append Text Lines

Append lines to an existing file:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $path := $dir || "todo.txt"
let $_ := exfile:write-text-lines($path, ("Buy groceries", "Walk the dog"))
let $_ := exfile:append-text-lines($path, ("Read a book", "Write some XQuery"))
return
    for $line at $n in exfile:read-text-lines($path)
    return
        $n || ". " || $line
```

## Write Serialized XML

The `exfile:write()` function serializes XQuery items (nodes, maps, strings) to a file using the standard serialization mechanism:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $doc :=
    <catalog>
        <book isbn="978-0596006341">
            <title>XQuery</title>
            <author>Priscilla Walmsley</author>
        </book>
        <book isbn="978-1491915103">
            <title>XQuery, 2nd Edition</title>
            <author>Priscilla Walmsley</author>
        </book>
    </catalog>
let $_ := exfile:write($dir || "catalog.xml", $doc)
return
    exfile:read-text($dir || "catalog.xml")
```

## Write Binary with Offset

Write binary data at a specific byte offset, overwriting existing bytes at that position:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $path := $dir || "patch.bin"
let $original := xs:base64Binary(xs:hexBinary("0000000000"))
let $patch := xs:base64Binary(xs:hexBinary("FFFF"))
let $_ := exfile:write-binary($path, $original)
let $_ := exfile:write-binary($path, $patch, 2)
return
    "Before: 0000000000, After: " || xs:hexBinary(exfile:read-binary($path))
```
