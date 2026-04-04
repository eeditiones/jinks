---
title: "Converting Roman Numerals with XQuery"
author: Joe Wicentowski
date: 2021-05-30
source: https://joewiz.org/2021/05/30/converting-roman-numerals-with-xquery-xslt/
---

# Converting Roman Numerals with XQuery

This article traces the evolution of a Roman numeral converter through several versions of XQuery, illustrating how features like maps, the arrow operator, and `fold-right()` can produce elegant, concise code.

## The Algorithm

The algorithm for converting Roman numerals to Arabic works right-to-left through the symbols: if the current value is less than the previous one, subtract it; otherwise, add it. For example, "XLIV" (44) works as: V=5 (add→5), I=1 (less than 5, subtract→4), L=50 (add→54), X=10 (less than 50, subtract→44).

## XQuery 3.1 Version

This version uses the arrow operator (`=>`), a map for symbol lookup, `analyze-string()` to split characters, and `fold-right()` for the accumulation logic:

```xquery
declare function local:decode-roman-numeral($roman-numeral as xs:string) as xs:integer {
    $roman-numeral
    => upper-case()
    => for-each(
        function($roman-numeral-uppercase) {
            analyze-string($roman-numeral-uppercase, ".")/fn:match/string()
        }
    )
    => for-each(
        map { "M": 1000, "D": 500, "C": 100, "L": 50, "X": 10, "V": 5, "I": 1 }
    )
    => fold-right( [0, 0],
        function($number as xs:integer, $accumulator as array(*)) {
            let $running-total := $accumulator?1
            let $previous-number := $accumulator?2
            return
                if ($number lt $previous-number) then
                    [ $running-total - $number, $number ]
                else
                    [ $running-total + $number, $number ]
        }
    )
    => array:head()
};

(
    local:decode-roman-numeral("vi"),
    local:decode-roman-numeral("xliv"),
    local:decode-roman-numeral("mcmxcix"),
    local:decode-roman-numeral("MMXXIV")
)
```

The pipeline reads naturally:
1. Convert to uppercase
2. Split into individual characters (via `analyze-string`)
3. Map each character to its integer value
4. Fold right-to-left, adding or subtracting each value
5. Extract the final total from the accumulator array

## How fold-right Works

The `fold-right()` function processes the sequence from right to left, carrying an *accumulator* — here an array of `[running-total, previous-number]`. Let's trace "XLIV":

| Step | Symbol | Value | Previous | Action | Total |
|------|--------|:-----:|:--------:|--------|:-----:|
| 1    | V      | 5     | 0        | 5 ≥ 0, add | 5 |
| 2    | I      | 1     | 5        | 1 < 5, subtract | 4 |
| 3    | L      | 50    | 1        | 50 ≥ 1, add | 54 |
| 4    | X      | 10    | 50       | 10 < 50, subtract | 44 |

## A Simpler Version Without fold-right

If `fold-right()` feels too advanced, here's an equivalent recursive approach:

```xquery
declare function local:roman-values($char as xs:string) as xs:integer {
    switch ($char)
        case "M" return 1000
        case "D" return 500
        case "C" return 100
        case "L" return 50
        case "X" return 10
        case "V" return 5
        case "I" return 1
        default return 0
};

declare function local:decode($chars as xs:string*, $prev as xs:integer) as xs:integer {
    if (empty($chars)) then 0
    else
        let $current := local:roman-values(head($chars))
        let $rest := local:decode(tail($chars), $current)
        return
            if ($current lt $prev) then $rest - $current
            else $rest + $current
};

declare function local:decode-roman($s as xs:string) as xs:integer {
    let $chars := analyze-string(upper-case($s), ".")/fn:match/string()
    return local:decode(reverse($chars), 0)
};

(
    local:decode-roman("vi"),
    local:decode-roman("xliv"),
    local:decode-roman("mcmxcix"),
    local:decode-roman("MMXXIV")
)
```
