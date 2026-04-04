---
title: "Wrangling Plain Text with XQuery"
author: Joe Wicentowski
date: 2012-02-06
source: https://joewiz.org/2012/02/06/an-under-appreciated-use-for-xquery-wrangling-plain-text/
---

# Wrangling Plain Text with XQuery

XQuery's regular-expression functions (`matches()`, `replace()`, and `tokenize()`), together with its excellent handling of sequences and recursive functions, provide all the tools one could need to tackle text wrangling tasks — even converting unstructured plain text into structured XML.

## The Challenge

Consider this indented outline of subjects from a Nixon Tapes subject log. The hierarchical structure is clear to the human eye, but converting it into nested XML is a real challenge:

```xquery
let $text := "The President left at 8:48 am
    -Administration recommendations on Capitol Hill
    -Improvements
    -Richardson's trip to New York
    -Health programs
            -Goals
            -Problems in present system
            -Approach
            -Emphasis on quality
    -Improvements in United States' health care
            -Maternal deaths
                    -Rate
                    -Decline
                    -United States' rate compared to other nations
                            -Reporting system
            -Data on health
                    -Differences in reporting system
            -Low-income people
                    -Whites
                    -Non-whites
            -Mortality rates
                    -Figures
    -Resource allocation
            -Rural areas
                    -Availability of care
            -Catastrophic care costs
            -Prevention
            -Problems"

return $text
```

## Step 1: Text to Lines

First, turn each line into a `<line>` element that captures the indent level:

```xquery
declare function local:text-to-lines($text as xs:string) {
    let $lines := tokenize($text, '\n')
    for $line in $lines
    let $level :=
        if (matches($line, '^\s')) then
            string-length(replace($line, '^(\s*).+$', '$1'))
        else
            0
    let $content := replace($line, '^\s*-?(.+)$', '$1')
    return
        <line level="{$level}">{$content}</line>
};

let $text := "The President left at 8:48 am
    -Administration recommendations
    -Health programs
            -Goals
            -Problems
    -Resource allocation
            -Rural areas"

return local:text-to-lines($text)
```

The `replace()` with `'^(\s*).+$'` isolates the leading whitespace, and `string-length()` counts it to determine the indent level.

## Step 2: Group Lines by Level

Next, group the flat sequence of lines into nested `<group>` elements according to their indent levels:

```xquery
declare function local:group-lines($lines as element(line)+) {
    let $first-line := $lines[1]
    let $level := $first-line/@level
    let $next-line-at-same-level := subsequence($lines, 2)[@level eq $level][1]
    let $group-of-lines :=
        if ($next-line-at-same-level) then
            subsequence($lines, 1, index-of($lines, $next-line-at-same-level) - 1)
        else
            $lines
    return (
        <group>{$group-of-lines}</group>,
        if ($next-line-at-same-level) then
            local:group-lines(
                subsequence($lines, index-of($lines, $next-line-at-same-level))
            )
        else ()
    )
};

declare function local:process-groups($groups as element(group)+) {
    if (count($groups) gt 1) then
        <group>{
            for $group in $groups
            return local:apply-levels($group)
        }</group>
    else
        local:apply-levels($groups)
};

declare function local:apply-levels($group as element(group)) {
    <group>
        {$group/line[1]}
        {
        if ($group/line[2]) then
            if (count(subsequence($group/line, 2)) gt 1) then
                <group>{
                    for $group in local:group-lines(subsequence($group/line, 2))
                    return local:apply-levels($group)
                }</group>
            else
                local:group-lines(subsequence($group/line, 2))
        else ()
        }
    </group>
};

declare function local:text-to-lines($text as xs:string) {
    let $lines := tokenize($text, '\n')
    for $line in $lines
    let $level :=
        if (matches($line, '^\s')) then
            string-length(replace($line, '^(\s*).+$', '$1'))
        else 0
    let $content := replace($line, '^\s*-?(.+)$', '$1')
    return
        <line level="{$level}">{$content}</line>
};

let $text := "The President left at 8:48 am
    -Health programs
            -Goals
            -Problems
    -Resource allocation
            -Rural areas"

let $lines := local:text-to-lines($text)
let $groups := local:group-lines($lines)
return local:process-groups($groups)
```

## Step 3: Groups to TEI List

Finally, transform the nested groups into a proper TEI `<list>`/`<item>` structure:

```xquery
declare function local:groups-to-list($group as element(group)) {
    <list>{local:inner-groups-to-list($group)}</list>
};

declare function local:inner-groups-to-list($group as element(group)) {
    if ($group/line) then
        for $item in $group/line
        return
            <item>{
                $item/text(),
                if ($item/following-sibling::group) then
                    <list>{local:inner-groups-to-list($item/following-sibling::group)}</list>
                else ()
            }</item>
    else
        for $g in $group/group
        return local:inner-groups-to-list($g)
};

declare function local:text-to-lines($text as xs:string) {
    let $lines := tokenize($text, '\n')
    for $line in $lines
    let $level :=
        if (matches($line, '^\s')) then
            string-length(replace($line, '^(\s*).+$', '$1'))
        else 0
    let $content := replace($line, '^\s*-?(.+)$', '$1')
    return
        <line level="{$level}">{$content}</line>
};

declare function local:group-lines($lines as element(line)+) {
    let $first-line := $lines[1]
    let $level := $first-line/@level
    let $next := subsequence($lines, 2)[@level eq $level][1]
    let $group :=
        if ($next) then subsequence($lines, 1, index-of($lines, $next) - 1)
        else $lines
    return (
        <group>{$group}</group>,
        if ($next) then local:group-lines(subsequence($lines, index-of($lines, $next)))
        else ()
    )
};

declare function local:process-groups($groups as element(group)+) {
    if (count($groups) gt 1) then
        <group>{for $g in $groups return local:apply-levels($g)}</group>
    else local:apply-levels($groups)
};

declare function local:apply-levels($group as element(group)) {
    <group>
        {$group/line[1]}
        {if ($group/line[2]) then
            if (count(subsequence($group/line, 2)) gt 1) then
                <group>{
                    for $g in local:group-lines(subsequence($group/line, 2))
                    return local:apply-levels($g)
                }</group>
            else local:group-lines(subsequence($group/line, 2))
        else ()}
    </group>
};

let $text := "The President left at 8:48 am
    -Health programs
            -Goals
            -Problems
    -Resource allocation
            -Rural areas
                    -Availability of care
            -Catastrophic care costs
            -Prevention"

let $lines := local:text-to-lines($text)
let $groups := local:group-lines($lines)
let $processed := local:process-groups($groups)
return local:groups-to-list($processed)
```

The result is a properly nested TEI list — from flat text to structured XML in one XQuery.
