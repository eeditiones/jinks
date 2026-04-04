# Generating HTML

XQuery can construct any XML — including HTML. This makes it a natural fit for generating web content directly from data.

## A Colored Table

Create a 10×10 table with alternating cell colors:

```xquery
declare namespace f="http://my-namespaces.org";

declare function f:background-color($x as xs:double, $y as xs:integer)
as xs:string {
    if ($x mod 2 + $y mod 2 <= 0) then "lightgreen"
    else if ($y mod 2 <= 0) then "yellow"
    else if ($x mod 2 <= 0) then "lightblue"
    else "white"
};

<body>
    <table>{
    for $y in 1 to 10 return
        <tr>
        {
            for $x in 1 to 10 return
                let $bg := f:background-color($x, $y),
                    $prod := $x * $y
                return
                    <td bgcolor="{$bg}">
                        {if ($y > 1 and $x > 1) then $prod else <b>{$prod}</b>}
                    </td>
        }
        </tr>
    }</table>
</body>
```

This combines nested FLWOR expressions with conditional XML construction. The first row and column are bolded as headers.

## A Multiplication Table

Generate a multiplication table with color-coded rows:

```xquery
declare variable $max := 12;

<table border="1" width="100%">
    <tr>
        <th>×</th>
        {
            for $i in 1 to $max
            return <th>{$i}</th>
        }
    </tr>
    {
        for $a in 1 to $max
        return
            <tr>
                <th>{$a}</th>
                {
                    for $b in 1 to $max
                    return
                        if ($a = $b) then
                            <td bgcolor="#F46978">{$a * $b}</td>
                        else if ($a mod 2 != 0) then
                            <td bgcolor="#A46978">{$a * $b}</td>
                        else
                            <td bgcolor="#A09224">{$a * $b}</td>
                }
            </tr>
    }
</table>
```

The diagonal (where row equals column) is highlighted in a distinct color — these are the perfect squares.

## Shakespeare's Structure

Generate a structured list of acts, scenes, and speakers from Hamlet:

<!-- context: data/shakespeare -->
```xquery
<html>
    <body>{
        for $act in doc("data/shakespeare/hamlet.xml")/PLAY/ACT
        return
            <ul>
                <li>
                    <h2>{$act/TITLE/text()}</h2>
                    <ul>
                    {
                        for $scene in $act/SCENE return
                            <li>
                                <h3>{$scene/TITLE/text()}</h3>
                                <ul>
                                {
                                    for $speaker in distinct-values($scene//SPEAKER)
                                    order by $speaker return
                                        <li>{$speaker}</li>
                                }
                                </ul>
                            </li>
                    }
                    </ul>
                </li>
            </ul>
    }</body>
</html>
```

This query traverses the hierarchical structure of the play — acts contain scenes, scenes contain speeches by speakers — and mirrors that hierarchy in the generated HTML.
