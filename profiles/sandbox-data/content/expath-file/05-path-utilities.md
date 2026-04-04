# Path Utilities

The EXPath File Module provides functions for manipulating and inspecting file paths without accessing the filesystem.

## Name

Extract the filename from a path:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

(
    exfile:name("/home/user/document.xml"),
    exfile:name("/home/user/projects/"),
    exfile:name("/")
)
```

## Parent

Get the parent directory of a path. The result always ends with the directory separator:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

(
    exfile:parent("/home/user/document.xml"),
    exfile:parent("/home/user/"),
    exfile:parent("/")
)
```

## Resolve Path

Resolve a relative path against the current working directory or a specified base:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

(
    "Resolved: " || exfile:resolve-path("data/input.xml"),
    "With base: " || exfile:resolve-path("child.txt", "/opt/app/config/")
)
```

## Path to URI

Convert a filesystem path to a `file://` URI:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

(
    exfile:path-to-uri("/tmp"),
    exfile:path-to-uri(exfile:temp-dir())
)
```

## Path to Native

Return the canonical, platform-native form of an existing path:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:path-to-native(exfile:temp-dir())
```

## Is Absolute

Test whether a path is absolute:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

(
    "/tmp/data.xml is absolute: " || exfile:is-absolute("/tmp/data.xml"),
    "relative/path is absolute: " || exfile:is-absolute("relative/path"),
    "temp-dir is absolute: " || exfile:is-absolute(exfile:temp-dir())
)
```

## Building Portable Paths

Combine path utilities with system properties to build paths that work across platforms:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

let $sep := exfile:dir-separator()
let $base := exfile:temp-dir()
let $project := string-join(("sandbox-demo", "project"), $sep)
let $full := $base || $project || $sep
let $_ := exfile:create-dir($full)
return (
    "Separator: " || $sep,
    "Base: " || $base,
    "Project dir: " || $full,
    "Exists: " || exfile:exists($full),
    "Name: " || exfile:name(exfile:parent($full)),
    "URI: " || exfile:path-to-uri($full)
)
```
