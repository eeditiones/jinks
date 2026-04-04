# Numbers and Dates

FunctX provides formatting, testing, and date manipulation functions.

## Formatting Numbers

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:pad-integer-to-length(12, 6),
    functx:pad-integer-to-length(1, 6),
    functx:ordinal-number-en(1),
    functx:ordinal-number-en(2),
    functx:ordinal-number-en(3),
    functx:ordinal-number-en(11),
    functx:ordinal-number-en(21)
)
```

**Expected:** `"000012"`, `"000001"`, `"1st"`, `"2nd"`, `"3rd"`, `"11th"`, `"21st"`

## Testing Numbers

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:is-a-number(123),
    functx:is-a-number('123'),
    functx:is-a-number('abc'),
    functx:is-a-number('12.5'),
    functx:between-inclusive(5, 1, 10),
    functx:between-exclusive(10, 1, 10)
)
```

## Averages with Empty Values

```xquery
import module namespace functx = "http://www.functx.com";

let $items :=
    <scores>
        <score>90</score>
        <score>85</score>
        <score/>
        <score>70</score>
    </scores>
return (
    (: fn:avg ignores empty elements :)
    avg($items/score[. != '']/xs:integer(.)),
    (: functx:avg-empty-is-zero counts them as 0 :)
    functx:avg-empty-is-zero($items/score/string(.))
)
```

## Constructing Dates

```xquery
import module namespace functx = "http://www.functx.com";

(
    functx:date(2024, 3, 15),
    functx:time(14, 30, 0),
    functx:mmddyyyy-to-date('12-15-2004'),
    functx:mmddyyyy-to-date('12152004'),
    functx:mmddyyyy-to-date('12/15/2004')
)
```

**Expected:** `2024-03-15`, `14:30:00`, `2004-12-15`, `2004-12-15`, `2004-12-15`

## Day of Week

```xquery
import module namespace functx = "http://www.functx.com";

let $date := xs:date('2024-03-15')
return (
    functx:day-of-week($date),
    functx:day-of-week-name-en($date),
    functx:day-of-week-abbrev-en($date)
)
```

## Month Functions

```xquery
import module namespace functx = "http://www.functx.com";

let $date := xs:date('2024-02-15')
return (
    functx:month-name-en($date),
    functx:month-abbrev-en($date),
    functx:days-in-month($date),
    functx:first-day-of-month($date),
    functx:last-day-of-month($date),
    functx:is-leap-year($date)
)
```

**Expected:** `"February"`, `"Feb"`, `29`, `2024-02-01`, `2024-02-29`, `true`

## Duration Calculations

```xquery
import module namespace functx = "http://www.functx.com";

let $dur := xs:dayTimeDuration('P1DT2H30M')
return (
    functx:total-hours-from-duration($dur),
    functx:total-minutes-from-duration($dur),
    functx:total-seconds-from-duration($dur),
    functx:total-days-from-duration($dur)
)
```

**Expected:** `26.5`, `1590`, `95400`, approximately `1.104`

## Date Navigation

```xquery
import module namespace functx = "http://www.functx.com";

let $date := xs:date('2024-03-15')
return (
    functx:next-day($date),
    functx:previous-day($date),
    functx:day-in-year($date),
    functx:add-months($date, 3),
    functx:first-day-of-year($date),
    functx:last-day-of-year($date)
)
```
