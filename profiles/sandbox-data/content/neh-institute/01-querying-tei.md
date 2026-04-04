# Querying TEI Documents

The Text Encoding Initiative (TEI) is the standard XML format for encoding texts in the humanities. XQuery is a natural fit for querying TEI documents — extracting speakers, dates, places, and structural elements.

## TEI Namespace

TEI documents use the namespace `http://www.tei-c.org/ns/1.0`. You must declare it before querying:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $doc := document {
<TEI xmlns="http://www.tei-c.org/ns/1.0">
    <teiHeader>
        <fileDesc>
            <titleStmt><title>A Sample Letter</title></titleStmt>
            <publicationStmt><p>Unpublished</p></publicationStmt>
            <sourceDesc><p>Born digital</p></sourceDesc>
        </fileDesc>
    </teiHeader>
    <text>
        <body>
            <opener>
                <dateline>
                    <placeName>Nashville</placeName>,
                    <date when="1862-03-15">March 15, 1862</date>
                </dateline>
                <salute>Dear <persName>Governor Johnson</persName>,</salute>
            </opener>
            <p>I write to inform you of developments in
                <placeName>Middle Tennessee</placeName>. The situation at
                <placeName>Fort Donelson</placeName> has changed considerably
                since <persName>General Grant</persName>'s arrival.</p>
            <p>The citizens of <placeName>Nashville</placeName> remain
                anxious about the coming weeks.</p>
            <closer>
                <salute>Your obedient servant,</salute>
                <signed><persName>James Smith</persName></signed>
            </closer>
        </body>
    </text>
</TEI>
}
return
    $doc//tei:title/string()
```

## Extracting Named Entities

TEI encodes people, places, and dates with dedicated elements. Extract them all:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $doc := document {
<TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text>
        <body>
            <opener>
                <dateline>
                    <placeName>Nashville</placeName>,
                    <date when="1862-03-15">March 15, 1862</date>
                </dateline>
                <salute>Dear <persName>Governor Johnson</persName>,</salute>
            </opener>
            <p>I write to inform you of developments in
                <placeName>Middle Tennessee</placeName>. The situation at
                <placeName>Fort Donelson</placeName> has changed considerably
                since <persName>General Grant</persName>'s arrival.</p>
            <p>The citizens of <placeName>Nashville</placeName> remain
                anxious about the coming weeks.</p>
            <closer>
                <salute>Your obedient servant,</salute>
                <signed><persName>James Smith</persName></signed>
            </closer>
        </body>
    </text>
</TEI>
}
return
    <entities>
        <people>{
            for $person in distinct-values($doc//tei:persName)
            order by $person
            return <person>{$person}</person>
        }</people>
        <places>{
            for $place in distinct-values($doc//tei:placeName)
            order by $place
            return <place>{$place}</place>
        }</places>
        <dates>{
            for $date in $doc//tei:date[@when]
            order by $date/@when
            return <date when="{$date/@when}">{$date/string()}</date>
        }</dates>
    </entities>
```

## Exploring Document Structure

TEI documents are hierarchically structured with nested `div` elements. Generate a structural outline:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $doc := document {
<TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text>
        <body>
            <div type="chapter" n="1">
                <head>The Boy</head>
                <div type="section" n="1.1">
                    <head>Early Years</head>
                    <p>Content here...</p>
                </div>
                <div type="section" n="1.2">
                    <head>Education</head>
                    <p>More content...</p>
                </div>
            </div>
            <div type="chapter" n="2">
                <head>The Man</head>
                <div type="section" n="2.1">
                    <head>Career</head>
                    <p>Content here...</p>
                </div>
            </div>
        </body>
    </text>
</TEI>
}
return
    <outline>{
        for $div in $doc//tei:div
        let $depth := count($div/ancestor::tei:div)
        let $indent := string-join((1 to $depth) ! "  ")
        return
            <item depth="{$depth}" type="{$div/@type}" n="{$div/@n}">
                {$div/tei:head/string()}
            </item>
    }</outline>
```

## Counting and Summarizing

Use XQuery to analyze a TEI document's composition:

```xquery
declare namespace tei = "http://www.tei-c.org/ns/1.0";

let $doc := document {
<TEI xmlns="http://www.tei-c.org/ns/1.0">
    <text>
        <body>
            <div type="chapter" n="1">
                <head>The Boy</head>
                <p>Among other public buildings in a certain town,
                    which for many reasons it will be prudent to refrain
                    from mentioning.</p>
                <p>The <persName>surgeon</persName> leaned over the body,
                    and raised the left hand near <placeName>London</placeName>.</p>
            </div>
            <div type="chapter" n="2">
                <head>The Man</head>
                <p>For the next eight or ten months,
                    <persName>Oliver</persName> was the victim of a
                    systematic course of treachery and deception.</p>
            </div>
        </body>
    </text>
</TEI>
}
return
    map {
        "paragraphs": count($doc//tei:p),
        "words": count(tokenize(string-join($doc//tei:p, ' '), '\s+')),
        "people": count(distinct-values($doc//tei:persName)),
        "places": count(distinct-values($doc//tei:placeName)),
        "chapters": count($doc//tei:div[@type = "chapter"])
    }
```
