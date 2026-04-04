# Practical Recipes

Real-world patterns for consuming APIs and web services from XQuery.

## Consuming a REST API

Fetch data from a JSON API and transform it to XML:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/json">
        <http:header name="Accept" value="application/json"/>
    </http:request>
)
let $data := parse-json(util:binary-to-string($response[2]))
return
    <slideshow title="{$data?slideshow?title}"
               author="{$data?slideshow?author}">
    {
        for $slide in $data?slideshow?slides?*
        return
            <slide title="{$slide?title}" type="{$slide?type}"/>
    }
    </slideshow>
```

## Fetching and Analyzing XML

Download an XML resource and examine its structure:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/xml"/>
)
return
    if ($response[1]/@status = "200") then
        let $doc := $response[2]
        return
            <analysis>
                <root-element>{local-name($doc/*)}</root-element>
                <child-count>{count($doc/*/*)}</child-count>
                <elements>{
                    for $name in distinct-values($doc/descendant::*/local-name())
                    return <element>{$name}</element>
                }</elements>
            </analysis>
    else
        <error>Failed to fetch XML: {string($response[1]/@status)}</error>
```

## Paginated API Calls

Many APIs return results in pages. Use a range to fetch all pages:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $pages :=
    for $page in 1 to 3
    let $url := "https://httpbin.org/get?page=" || $page || "&amp;per_page=10"
    let $response := http:send-request(
        <http:request method="GET" href="{$url}">
            <http:header name="Accept" value="application/json"/>
        </http:request>
    )
    return
        if ($response[1]/@status = "200") then
            let $data := parse-json(util:binary-to-string($response[2]))
            return
                <page number="{$page}">
                    <url>{$data?url}</url>
                </page>
        else
            <page number="{$page}" error="{$response[1]/@status}"/>

return
    <all-pages>{$pages}</all-pages>
```

## Checking Resource Existence

Use HEAD to check if a resource exists without downloading the body:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $urls := (
    "https://httpbin.org/get",
    "https://httpbin.org/status/404",
    "https://httpbin.org/status/301"
)
return
    <url-check>
    {
        for $url in $urls
        let $response := http:send-request(
            <http:request method="HEAD" href="{$url}" timeout="5"
                          follow-redirect="false"/>
        )
        let $status := xs:integer($response[1]/@status)
        return
            <url href="{$url}"
                 status="{$status}"
                 exists="{$status ge 200 and $status lt 400}"/>
    }
    </url-check>
```

## Comparing API Response Formats

Request different formats from the same API and compare:

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $endpoints := map {
    "json": "https://httpbin.org/get",
    "xml": "https://httpbin.org/xml",
    "html": "https://httpbin.org/html"
}
return
    <format-comparison>
    {
        for $format in map:keys($endpoints)
        let $response := http:send-request(
            <http:request method="GET" href="{$endpoints($format)}"/>
        )
        let $body := $response[2]
        return
            <format name="{$format}">
                <status>{string($response[1]/@status)}</status>
                <content-type>{
                    $response[1]/http:header[lower-case(@name) = "content-type"]/@value/string()
                }</content-type>
                <body-type>{
                    if ($body instance of document-node()) then "document-node"
                    else if ($body instance of xs:string) then "xs:string"
                    else if ($body instance of xs:base64Binary) then "xs:base64Binary"
                    else "other"
                }</body-type>
            </format>
    }
    </format-comparison>
```

## Parsing CSV from a Text Response

Fetch text data and transform it to XML (using a robots.txt as an example of line-oriented text):

```xquery
import module namespace http = "http://expath.org/ns/http-client";

let $response := http:send-request(
    <http:request method="GET" href="https://httpbin.org/robots.txt"/>
)
let $text := $response[2]
let $lines := tokenize($text, "\n")
return
    <robots-txt>
        <line-count>{count($lines)}</line-count>
        {
            for $line in $lines
            where normalize-space($line) ne ""
            let $parts := tokenize($line, ":\s*")
            return
                <rule directive="{$parts[1]}" value="{string-join(subsequence($parts, 2), ': ')}"/>
        }
    </robots-txt>
```
