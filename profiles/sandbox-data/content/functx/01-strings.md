# String Functions

The FunctX library provides many useful string functions that complement XQuery's built-in `fn:` functions. Import the library to use them.

> **Note:** The FunctX library must be installed in eXist-db. Install it via the Package Manager, or import it from the web.

## Trimming Whitespace

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:trim('   xyz   '),
    functx:left-trim('   xyz   '),
    functx:right-trim('   xyz   ')
)
```

**Expected:** `"xyz"`, `"xyz   "`, `"   xyz"`

## Capitalization

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:capitalize-first('hello world'),
    functx:camel-case-to-words('thisIsACamelCaseTerm', ' '),
    functx:words-to-camel-case('this Is A Term')
)
```

**Expected:** `"Hello world"`, `"this Is A Camel Case Term"`, `"thisIsATerm"`

## Contains as a Whole Word

`fn:contains()` matches substrings, but `functx:contains-word()` only matches whole words:

```xquery
import module namespace functx = "http://www.functx.com";

(
    fn:contains('abcdef', 'abc'),
    functx:contains-word('abcdef', 'abc'),
    functx:contains-word('abc def ghi', 'def'),
    functx:contains-word('abc.def.ghi', 'def'),
    functx:contains-case-insensitive('Hello World', 'hello'),
    functx:contains-any-of('hello world', ('world', 'earth'))
)
```

**Expected:** `true`, `false`, `true`, `true`, `true`, `true`

## Replacing the First Match

`fn:replace()` replaces all matches. `functx:replace-first()` replaces only the first:

```xquery
import module namespace functx = "http://www.functx.com";

(
    fn:replace('abcabcabc', 'ab', 'X'),
    functx:replace-first('abcabcabc', 'ab', 'X'),
    functx:replace-first('9999-9999', '\d+', 'X')
)
```

**Expected:** `"XcXcXc"`, `"Xcabcabc"`, `"X-9999"`

## Substrings by Last Occurrence

XQuery's `fn:substring-before()` and `fn:substring-after()` find the *first* occurrence. FunctX adds last-occurrence variants:

```xquery
import module namespace functx = "http://www.functx.com";

(
    fn:substring-before('abc-def-ghi', '-'),
    functx:substring-before-last('abc-def-ghi', '-'),
    fn:substring-after('abc-def-ghi', '-'),
    functx:substring-after-last('abc-def-ghi', '-')
)
```

**Expected:** `"abc"`, `"abc-def"`, `"def-ghi"`, `"ghi"`

## String Statistics

```xquery
import module namespace functx = "http://www.functx.com";

let $text := "To be, or not to be,
that is the question."
return (
    functx:word-count($text),
    functx:line-count($text),
    functx:max-line-length($text)
)
```

## Splitting Strings

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:chars('hello'),
    functx:lines('line one
line two
line three'),
    functx:escape-for-regex('price is $5.00 (USD)'),
    functx:reverse-string('hello')
)
```

## Padding and Repeating

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:pad-string-to-length('abc', '*', 10),
    functx:repeat-string('=-', 20)
)
```
