# Error Handling

The EXPath File Module uses spec-defined error codes in the `http://expath.org/ns/file` namespace. These can be caught with XQuery's `try`/`catch` mechanism for robust file handling.

## Error Codes

The module defines 9 error codes:

| Error | Meaning |
|-------|---------|
| `exfile:not-found` | Path does not exist |
| `exfile:invalid-path` | Path string is malformed |
| `exfile:exists` | Path already exists (when it shouldn't) |
| `exfile:no-dir` | Expected a directory, but path is not one |
| `exfile:is-dir` | Expected a file, but path is a directory |
| `exfile:unknown-encoding` | Unsupported character encoding |
| `exfile:out-of-range` | Offset or length out of bounds |
| `exfile:io-error` | General I/O error |

## Catching File Errors

Use `try`/`catch` with the EXPath error namespace to handle specific file errors:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

try {
    exfile:read-text("/this/file/does/not/exist.txt")
} catch exfile:not-found {
    "File not found: " || $err:description
}
```

## Handling Multiple Error Types

Catch different error codes for different recovery strategies:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:create-dir($dir)
return
    try {
        exfile:read-text($dir)
    } catch exfile:is-dir {
        "Cannot read a directory as text. Listing contents instead: " ||
        string-join(exfile:list($dir), ", ")
    } catch exfile:not-found {
        "File not found"
    }
```

## Safe File Reading

A pattern for reading a file with a fallback default:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

declare function local:read-or-default($path as xs:string, $default as xs:string) as xs:string {
    if (exfile:exists($path) and exfile:is-file($path)) then
        exfile:read-text($path)
    else
        $default
};

let $dir := exfile:temp-dir() || "sandbox-demo/"
return (
    "Missing file: " || local:read-or-default($dir || "missing.txt", "(default value)"),
    "Directory: " || local:read-or-default($dir, "(not a file)")
)
```

## File Properties for Validation

Check file properties before performing operations:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/validate/"
let $_ := exfile:create-dir($dir)
let $_ := exfile:write-text($dir || "data.txt", "Sample content here")
let $path := $dir || "data.txt"
return
    if (not(exfile:exists($path))) then
        <error>File not found: {$path}</error>
    else if (exfile:is-dir($path)) then
        <error>Path is a directory: {$path}</error>
    else
        <file>
            <name>{exfile:name($path)}</name>
            <size>{exfile:size($path)} bytes</size>
            <modified>{exfile:last-modified($path)}</modified>
            <content>{exfile:read-text($path)}</content>
        </file>
```

## Encoding Errors

The `exfile:unknown-encoding` error is raised when an unsupported encoding is specified:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $dir := exfile:temp-dir() || "sandbox-demo/"
let $_ := exfile:write-text($dir || "test.txt", "hello")
return
    try {
        exfile:read-text($dir || "test.txt", "KLINGON-UTF-8")
    } catch exfile:unknown-encoding {
        "Unsupported encoding: " || $err:description
    }
```

## Cleanup Pattern

Ensure temporary files are cleaned up even if processing fails:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $work-dir := exfile:create-temp-dir("work-", "-tmp", exfile:temp-dir())
return
    try {
        let $_ := exfile:write-text($work-dir || "step1.txt", "intermediate data")
        let $_ := exfile:write-text($work-dir || "step2.txt", "more data")
        let $result := exfile:read-text($work-dir || "step1.txt") || " + " ||
                       exfile:read-text($work-dir || "step2.txt")
        let $_ := exfile:delete($work-dir, true())
        return
            <success cleaned="{not(exfile:exists($work-dir))}">{$result}</success>
    } catch * {
        let $_ := (
            if (exfile:exists($work-dir)) then exfile:delete($work-dir, true()) else ()
        )
        return
            <error>{$err:description}</error>
    }
```
