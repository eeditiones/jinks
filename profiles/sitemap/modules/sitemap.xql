xquery version "3.1";

module namespace sitemap="http://tei-publisher.org/api/sitemap";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace router="http://e-editiones.org/roaster";
import module namespace tmpl="http://e-editiones.org/xquery/templates";

declare variable $sitemap:app-base :=
    request:get-scheme() || "://" || request:get-server-name() || ":" ||
    request:get-server-port() ||
    request:get-context-path() || "/apps/" ||
    substring-after($config:app-root, repo:get-root());

(:~
 : Get the stored sitemap.xml file.
 :
 : @param $request The request map from roaster
 : @return HTTP response with sitemap.xml or 404 if not found
 :)
declare function sitemap:get-sitemap($request as map(*)) {
    let $sitemapPath := $config:app-root || "/sitemap.xml"
    return
        if (doc-available($sitemapPath)) then
            let $baseUri :=
                let $cfg := json-doc($config:app-root || "/context.json")
                return
                    if ($cfg?features?sitemap?base-uri) then
                        $cfg?features?sitemap?base-uri
                    else
                        $sitemap:app-base
            let $template := serialize(doc($sitemapPath))
            let $expanded := tmpl:process($template, map { "baseUri": $baseUri }, map { "plainText": false() })
            return
                router:response(200, "application/xml", $expanded)
        else
            router:response(404, "text/plain", "Sitemap not found. Please generate it first using POST /api/actions/sitemap")
};

(:~
 : Generate a sitemap.xml via roaster/Open API endpoint.
 :
 : @param $request The request map from roaster
 : @return HTTP response with sitemap.xml
 :)
declare function sitemap:generate-sitemap($request as map(*)) {
    let $config := json-doc($config:app-root || "/context.json")
    let $sitemap := sitemap:generate($sitemap:app-base, $config)
    let $stored := xmldb:store($config:app-root, "sitemap.xml", $sitemap, "application/xml")
    return [
        map {
            "type": "actions:sitemap",
            "message": "Sitemap generated in " || $stored
        }
    ]
};

(:~
 : Generate a sitemap.xml by crawling the application. URLs are stored with a
 : [[ $baseUri ]] placeholder that is substituted at serve time by sitemap:get-sitemap.
 :
 : @param $appBase The base URI for API calls (e.g., http://localhost:8080/exist/apps/tp10)
 : @return sitemap.xml document
 :)
declare %private function sitemap:generate($appBase as xs:string, $config as map(*)) as document-node() {
    let $urls := sitemap:crawl($appBase)
    return
        document {
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            {
                for $url in $config?features?sitemap?custom?*
                return
                    <url><loc>[[ $baseUri ]]/{$url}</loc></url>,
                for $url in $urls
                return
                    <url><loc>[[ $baseUri ]]/{$url}</loc></url>
            }
            </urlset>
        }
};

(:~
 : Crawl the application and collect all URLs.
 :
 : @param $appBase The base URI for API calls
 : @return sequence of relative URL strings (without base URI)
 :)
declare %private function sitemap:crawl($appBase as xs:string) as xs:string* {
    let $documents := sitemap:get-documents($appBase)
    let $urls :=
        for $doc in $documents?*
        return
            (: Add all pages for this document :)
            sitemap:get-document-pages($appBase, $doc)
    return
        distinct-values($urls)
};

(:~
 : Get the list of documents from the api/documents endpoint.
 :
 : @param $appBase The base URI of the application
 : @return array of document maps, each containing a path property
 :)
declare %private function sitemap:get-documents($appBase as xs:string) as array(*) {
    let $request := 
        <http:request method="GET" href="{$appBase}/api/documents"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $data := util:binary-to-string(xs:base64Binary($response[2]))
            return
                parse-json($data)
        else
            error(xs:QName("sitemap:ERROR"), "Failed to fetch documents: " || $response[1]/@status)
};

(:~
 : Get all pages for a document by calling the parts endpoint and following pagination.
 :
 : @param $appBase The base URI for API calls
 : @param $doc The document map containing path and other metadata
 : @return sequence of relative URL strings for all pages of the document
 :)
declare %private function sitemap:get-document-pages($appBase as xs:string, $doc as map(*)) as xs:string* {
    sitemap:get-document-pages-recursive($appBase, $doc, (), ())
};

(:~
 : Recursively get all pages for a document by following nextId/next pagination.
 :
 : @param $appBase The base URI for API calls
 : @param $doc The document map containing path and other metadata
 : @param $id Optional id parameter for pagination
 : @param $root Optional root parameter for pagination
 : @return sequence of relative URL strings for all pages of the document
 :)
declare %private function sitemap:get-document-pages-recursive(
    $appBase as xs:string,
    $doc as map(*), 
    $id as xs:string?,
    $root as xs:string?
) as xs:string* {
    let $path := $doc?path
    let $paramList := 
        (
            "serialize=xml",
            "content=none",
            "view=" || encode-for-uri($doc?view),
            if ($id) then 
                "id=" || encode-for-uri($id) 
            else if ($root) then 
                "root=" || encode-for-uri($root) 
            else 
                ()
        )[. != ""]
    let $params := string-join($paramList, "&amp;")
    let $url := $appBase || "/api/parts/" || encode-for-uri($path) || "/json?" || $params
    let $request := 
        <http:request method="GET" href="{$url}"/>
    let $_ := util:log("INFO", ("Sitemap: Getting document pages for ", $url))
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $data := util:binary-to-string(xs:base64Binary($response[2]))
            let $json := parse-json($data)
            let $currentUrl :=
                if (map:contains($json, "id") and $json?id != "") then
                    $path || "?id=" || encode-for-uri($json?id)
                else if (map:contains($json, "rootNode") and $json?rootNode != "") then
                    $path || "?root=" || encode-for-uri($json?rootNode)
                else
                    $path
            let $nextId := if (map:contains($json, "nextId") and $json?nextId != "") then $json?nextId else ()
            let $next := if (map:contains($json, "next") and $json?next != "") then $json?next else ()
            return (
                $currentUrl,
                if ($nextId) then
                    sitemap:get-document-pages-recursive($appBase, $doc, $nextId, ())
                else if ($next) then
                    sitemap:get-document-pages-recursive($appBase, $doc, (), $next)
                else
                    ()
            )
        else
            (: If the request fails, just return the base path :)
            $path
};
