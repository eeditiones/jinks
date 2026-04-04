# Directory Operations

The EXPath File Module provides functions for creating, listing, and navigating directories.

## Create Directory

Create a directory, including any necessary parent directories:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/a/b/c/"
let $_ := exfile:create-dir($dir)
return
    exfile:is-dir($dir)
```

## Create Temporary Directory

Create a temporary directory with a prefix and suffix. The result is the full path of the new directory:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $tmp := exfile:create-temp-dir("sandbox-", "-work", exfile:temp-dir())
return (
    "Created: " || $tmp,
    "Is directory: " || exfile:is-dir($tmp)
)
```

## Create Temporary File

Create a temporary file:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $tmp := exfile:create-temp-file("data-", ".csv", exfile:temp-dir())
let $_ := exfile:write-text($tmp, "name,age&#10;Alice,30&#10;Bob,25")
return (
    "File: " || exfile:name($tmp),
    "Content: " || exfile:read-text($tmp)
)
```

## List Directory Contents

List files and subdirectories. Subdirectory names end with the directory separator:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/listing/"
let $_ := exfile:create-dir($dir)
let $_ := exfile:create-dir($dir || "subdir")
let $_ := exfile:write-text($dir || "readme.txt", "hello")
let $_ := exfile:write-text($dir || "data.xml", "<root/>")
return
    exfile:list($dir)
```

## List with Glob Pattern

Filter the listing with a glob pattern (`*` and `?` wildcards):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/glob/"
let $_ := exfile:create-dir($dir)
let $_ := exfile:write-text($dir || "report-2024.csv", "")
let $_ := exfile:write-text($dir || "report-2025.csv", "")
let $_ := exfile:write-text($dir || "notes.txt", "")
let $_ := exfile:write-text($dir || "image.png", "")
return (
    "*.csv: " || string-join(exfile:list($dir, false(), "*.csv"), ", "),
    "report*: " || string-join(exfile:list($dir, false(), "report*"), ", ")
)
```

## List Recursively

Set the `$recursive` parameter to `true()` to include contents of subdirectories:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/tree/"
let $_ := exfile:create-dir($dir || "src/main")
let $_ := exfile:create-dir($dir || "src/test")
let $_ := exfile:write-text($dir || "src/main/app.xq", "1")
let $_ := exfile:write-text($dir || "src/test/test.xq", "1")
let $_ := exfile:write-text($dir || "README.md", "1")
return
    exfile:list($dir, true())
```

## Children and Descendants

`exfile:children()` returns absolute paths of a directory's immediate children. `exfile:descendants()` returns all nested paths recursively:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/nav/"
let $_ := exfile:create-dir($dir || "docs")
let $_ := exfile:write-text($dir || "index.html", "")
let $_ := exfile:write-text($dir || "docs/guide.html", "")
return (
    "Children:",
    for $c in exfile:children($dir) return "  " || exfile:name($c),
    "Descendants:",
    for $d in exfile:descendants($dir) return "  " || exfile:name($d)
)
```

## Copy, Move, Delete

Copy and move files or entire directory trees. Delete with optional recursive flag:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/ops/"
let $_ := exfile:create-dir($dir)
(: Write, copy, move :)
let $_ := exfile:write-text($dir || "original.txt", "Important data")
let $_ := exfile:copy($dir || "original.txt", $dir || "backup.txt")
let $_ := exfile:move($dir || "original.txt", $dir || "renamed.txt")
return (
    "original.txt exists: " || exfile:exists($dir || "original.txt"),
    "backup.txt exists: " || exfile:exists($dir || "backup.txt"),
    "renamed.txt exists: " || exfile:exists($dir || "renamed.txt"),
    "backup content: " || exfile:read-text($dir || "backup.txt")
)
```

Delete a directory and all its contents:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/cleanup/"
let $_ := exfile:create-dir($dir || "deep/nested")
let $_ := exfile:write-text($dir || "deep/nested/file.txt", "data")
let $before := exfile:exists($dir)
let $_ := exfile:delete($dir, true())
let $after := exfile:exists($dir)
return (
    "Before delete: " || $before,
    "After delete: " || $after
)
```
