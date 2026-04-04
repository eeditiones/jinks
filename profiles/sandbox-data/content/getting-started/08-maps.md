# Maps

XQuery 3.1 introduced maps — key-value data structures that complement XML for working with structured data.

## Creating and Accessing Maps

A map is constructed with `map { }` and accessed with the `()` or `?` operator:

```xquery
let $week := map {
    0: "Sonntag", 1: "Montag", 2: "Dienstag",
    3: "Mittwoch", 4: "Donnerstag",
    5: "Freitag", 6: "Samstag"
}
return
    $week(3)
```

This returns "Mittwoch" (Wednesday in German).

## The Lookup Operator

The `?` operator provides a concise way to look up map entries:

```xquery
let $week := map {
    "sunday": "Sonntag", "monday": "Montag",
    "tuesday": "Dienstag", "wednesday": "Mittwoch",
    "thursday": "Donnerstag", "friday": "Freitag",
    "saturday": "Samstag"
}
return
    $week?thursday
```

## Maps with Date Keys

Map keys can be any atomic type, including dates:

```xquery
<table class="table">
{
    let $birthdays := map {
        xs:date("1975-03-19") : "Uschi",
        xs:date("1980-01-22") : "Verona",
        xs:date("1960-06-14") : "Heinz",
        xs:date("1963-10-21") : "Roland"
    }
    for $key in map:keys($birthdays)
    let $name := $birthdays($key)
    order by $name ascending
    return
        <tr>
            <td>{$name}</td>
            <td>{format-date($key, "[MNn] [D00], [Y0000]")}</td>
        </tr>
}
</table>
```

The `format-date()` function formats dates using a picture string — `[MNn]` gives the month name, `[D00]` the zero-padded day, and `[Y0000]` the four-digit year.

## Iterating with map:for-each

The `map:for-each` function (called `map:for-each-entry` in some implementations) applies a function to each key-value pair:

```xquery
<table class="table">
{
    let $birthdays := map {
        xs:date("1975-03-19") : "Uschi",
        xs:date("1980-01-22") : "Verona",
        xs:date("1960-06-14") : "Heinz",
        xs:date("1963-10-21") : "Roland"
    }
    return
        map:for-each($birthdays, function($date, $name) {
            <tr>
                <td>{$name}</td>
                <td>{format-date($date, "[MNn] [D00], [Y0000]")}</td>
            </tr>
        })
}
</table>
```

This is often cleaner than using `map:keys()` followed by lookups, especially when you need both the key and value.
