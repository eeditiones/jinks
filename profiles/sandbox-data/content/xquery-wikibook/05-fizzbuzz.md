# FizzBuzz and Other Puzzles

The classic FizzBuzz problem: print numbers from 1 to 100, but replace multiples of 3 with "Fizz", multiples of 5 with "Buzz", and multiples of both with "FizzBuzz". XQuery offers several elegant approaches.

## Classic If/Then/Else

The straightforward approach:

```xquery
for $n in 1 to 100
let $fizz := if ($n mod 3 = 0) then "Fizz" else ()
let $buzz := if ($n mod 5 = 0) then "Buzz" else ()
return
    if ($fizz or $buzz) then concat($fizz, $buzz)
    else $n
```

The key insight: `$fizz` and `$buzz` are either strings or empty sequences. `concat()` ignores empty sequences, so "FizzBuzz" emerges naturally when both match.

## No If/Then/Else

An elegant pure-XPath solution by Dimitre Novatchev that avoids explicit conditionals:

```xquery
for $n in 1 to 100,
    $fizz in not($n mod 3),
    $buzz in not($n mod 5)
return
    concat("fizz"[$fizz], "buzz"[$buzz], $n[not($fizz or $buzz)])
```

This exploits XPath predicates as filters: `"fizz"[$fizz]` returns "fizz" when `$fizz` is true, or an empty sequence when false. The `$n[not($fizz or $buzz)]` returns the number only when neither Fizz nor Buzz applies.

## One-Liner

The most concise version:

```xquery
(1 to 100) ! (
    (("fizz"[. mod 3 = 0] || "buzz"[. mod 5 = 0])[.], .)[1]
)
```

## Configurable FizzBuzz

A data-driven approach where the rules come from an XML configuration:

```xquery
let $config :=
    <fizzbuzz>
        <range min="1" max="30"/>
        <test>
            <mod value="3" test="0">Fizz</mod>
            <mod value="5" test="0">Buzz</mod>
        </test>
    </fizzbuzz>
return
    string-join(
        for $i in ($config/range/@min to $config/range/@max)
        let $s :=
            for $mod in $config/test/mod
            return
                if ($i mod $mod/@value = $mod/@test)
                then string($mod)
                else ()
        return
            if (exists($s)) then string-join($s, ' ')
            else string($i),
        '&#10;'
    )
```

Add more `<mod>` elements to extend the game — for example, `<mod value="7" test="0">Bazz</mod>`.
