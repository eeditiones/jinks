# System Properties

The EXPath File Module provides functions for querying filesystem properties — separators, temporary directories, and the current working directory. These are essential for writing portable file-handling code that works across operating systems.

## Directory Separator

The platform's directory separator character (`/` on Unix, `\` on Windows):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:dir-separator()
```

## Line Separator

The platform's default line separator (`&#10;` on Unix, `&#13;&#10;` on Windows):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

string-to-codepoints(exfile:line-separator())
```

## Path Separator

The character used to separate entries in the system PATH (`:` on Unix, `;` on Windows):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:path-separator()
```

## Temporary Directory

The system's default temporary directory. The result always ends with the directory separator:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:temp-dir()
```

## Current Directory

The working directory of the eXist-db process:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:current-dir()
```

## Base Directory

The base directory derived from the XQuery static base URI. Returns the empty sequence when no file-based base URI is set:

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:base-dir()
```

## Filesystem Roots

List the root directories of the filesystem (`/` on Unix, `C:\`, `D:\`, etc. on Windows):

```xquery
import module namespace exfile = "http://expath.org/ns/file";

exfile:list-roots()
```
