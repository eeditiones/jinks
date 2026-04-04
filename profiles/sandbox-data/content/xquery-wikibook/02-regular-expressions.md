# Regular Expressions

XQuery provides three core functions for working with regular expressions: `matches()`, `replace()`, and `tokenize()`.

## matches()

Test whether a string matches a pattern:

```xquery
let $input := 'Hello World'
return
    <results>
        <basic>{matches($input, 'Hello World')}</basic>
        <wildcard>{matches($input, 'H.*o W.*d')}</wildcard>
        <quantifiers>{matches($input, 'Hel+o? W.+d')}</quantifiers>
        <case-insensitive>{matches($input, 'hello', 'i')}</case-insensitive>
        <free-spacing>{matches($input, 'he l lo', 'ix')}</free-spacing>
        <anchored-start>{matches($input, '^Hello')}</anchored-start>
        <anchored-both>{matches($input, '^Hello$')}</anchored-both>
    </results>
```

The `i` flag enables case-insensitive matching. The `x` flag enables free-spacing mode where whitespace in the pattern is ignored.

## tokenize()

Split a string into a sequence of substrings:

```xquery
let $simple := 'red,orange,yellow,green,blue'
let $messy := 'red   ,  orange ,   yellow  ,  green ,  blue'
return (
    tokenize($simple, ','),
    tokenize($messy, '\s*,\s*')
)
```

The regex `\s*,\s*` handles commas surrounded by any amount of whitespace.

## replace()

Replace parts of a string using patterns:

```xquery
let $input := 'Hello World'
return (
    replace($input, 'o', 'O'),
    replace($input, '.', 'X'),
    replace($input, 'H.*?o', 'Bye')
)
```

## Capture Groups

Use parentheses for capture groups and `$1`, `$2` for back-references:

```xquery
let $input := 'Chapter 1 and Chapter 2'
return
    replace($input, "Chapter (\d)", "Section $1.0")
```

This replaces "Chapter 1" with "Section 1.0" — the `$1` refers to the first captured group (the digit).

## Practical Example: Stopword Filtering

Filter out common words from text using sequence comparison:

```xquery
let $stopwords := ("a", "and", "in", "the", "or", "over")
let $input := 'a quick brown fox jumps over the lazy dog'
let $words := tokenize($input, '\s+')
return
    <results>
        <filtered>{
            string-join(
                for $word in $words
                where not($stopwords = $word)
                return $word,
                ' '
            )
        }</filtered>
        <word-analysis>{
            for $word in $words
            return
                <word on-stop-list="{$stopwords = $word}">{$word}</word>
        }</word-analysis>
    </results>
```

The expression `$stopwords = $word` uses XQuery's general comparison, which returns `true` if *any* item in `$stopwords` equals `$word`.
