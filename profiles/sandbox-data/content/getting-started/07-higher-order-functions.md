# Higher-Order Functions

XQuery 3.0 treats functions as first-class values. You can assign functions to variables, pass them as arguments, and return them from other functions.

## Inline Functions

Define a function inline and pass it as an argument:

```xquery
declare namespace ex="http://exist-db.org/xquery/ex";

declare function ex:apply($func, $list) {
    for $item in $list return $func($item)
};

let $f := function($a) { upper-case($a) }
return
    ex:apply($f, ("Hello", "world!"))
```

The inline function `function($a) { upper-case($a) }` is assigned to `$f` and then passed to `ex:apply`, which calls it on each item.

## Named Function References

Use the `#` syntax to reference an existing function by name and arity:

```xquery
declare namespace ex="http://exist-db.org/xquery/ex";

declare function ex:apply($func as function(item()) as item()*, $list) {
    for $item in $list return $func($item)
};

let $fApply := ex:apply#2
return
    $fApply(function($a) { upper-case($a) }, ("Hello", "world!"))
```

`ex:apply#2` creates a reference to the `ex:apply` function with arity 2 (two parameters).

## Dynamic Function Lookup

Resolve a function at runtime using `function-lookup()`:

```xquery
declare namespace ex="http://exist-db.org/xquery/ex2";

declare function ex:fold-left(
        $f as function(item()*, item()) as item()*,
        $zero as item()*,
        $seq as item()*) as item()* {
    if (fn:empty($seq)) then $zero
    else ex:fold-left($f, $f($zero, $seq[1]), subsequence($seq, 2))
};

let $foldLeft := function-lookup(xs:QName("ex:fold-left"), 3)
return
    $foldLeft(function($a, $b) { $a * $b }, 1, 1 to 5)
```

This computes the factorial of 5 (120) by folding multiplication over the sequence 1 to 5.

## Built-in Higher-Order Functions

XQuery provides several higher-order functions in the standard library:

### for-each

Apply a function to each item in a sequence:

```xquery
for-each(1 to 5, function($a) { $a * $a })
```

### filter

Keep only the items that satisfy a predicate:

```xquery
fn:filter(1 to 10, function($a) { $a mod 2 = 0 })
```

## Closures

An inline function captures variables from its surrounding scope:

```xquery
declare function local:apply($names as xs:string*, $f as function(xs:string) as xs:string) {
    for $name in $names
    return
        $f($name)
};

let $greeting := "Hello "
let $f := function($name as xs:string) {
    (: $greeting is captured from the enclosing scope :)
    $greeting || $name
}
return
    local:apply(("Hans", "Rudi"), $f)
```

The variable `$greeting` is "closed over" — it's available inside `$f` even when `$f` is called from within `local:apply`.

## Partial Application

Use `?` as a placeholder to create a new function with some arguments pre-filled:

```xquery
declare namespace ex="http://exist-db.org/xquery/ex";

declare function ex:multiply($base, $number) {
    $base * $number
};

let $times10 := ex:multiply(10, ?)
return
    for-each(1 to 10, $times10)
```

`ex:multiply(10, ?)` creates a new function that multiplies its argument by 10. This is called *partial application* — you supply some arguments now and the rest later.
