xquery version "3.1";

module namespace sitemap="http://tei-publisher.org/api/sitemap";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace router="http://e-editiones.org/roaster";

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
            router:response(200, "application/xml", doc($sitemapPath))
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
    let $appBase := 
        request:get-scheme() || "://" || request:get-server-name() || ":" || 
        request:get-server-port() ||
        request:get-context-path() || "/apps/" ||
        substring-after($config:app-root, repo:get-root())
    let $config := json-doc($config:app-root || "/context.json")
    let $baseUri :=
        if ($config?features?sitemap?base-uri) then
            $config?features?sitemap?base-uri
        else
            $appBase
    let $sitemap := sitemap:generate($appBase, $baseUri)
    let $stored := xmldb:store($config:app-root, "sitemap.xml", $sitemap, "application/xml")
    return [
        map {
            "type": "actions:sitemap",
            "message": "Sitemap generated in " || $stored
        }
    ]
};

(:~
 : Generate a sitemap.xml by crawling the application.
 :
 : @param $appBase The base URI for API calls (e.g., http://localhost:8080/exist/apps/tp10)
 : @param $baseUri The base URI to use in sitemap URLs (can be different, e.g., production URL)
 : @return sitemap.xml document
 :)
declare %private function sitemap:generate($appBase as xs:string, $baseUri as xs:string) as document-node() {
    let $urls := sitemap:crawl($appBase, $baseUri)
    return
        document {
            <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            {
                for $url in $urls
                return
                    <url>
                        <loc>{$url}</loc>
                    </url>
            }
            </urlset>
        }
};

(:~
 : Crawl the application and collect all URLs.
 :
 : @param $appBase The base URI for API calls
 : @param $baseUri The base URI to use in sitemap URLs
 : @return sequence of URL strings
 :)
declare %private function sitemap:crawl($appBase as xs:string, $baseUri as xs:string) as xs:string* {
    let $documents := sitemap:get-documents($appBase)
    let $urls :=
        for $doc in $documents?*
        return
            (: Add all pages for this document :)
            sitemap:get-document-pages($appBase, $baseUri, $doc)
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
 : @param $baseUri The base URI to use in sitemap URLs
 : @param $doc The document map containing path and other metadata
 : @return sequence of URL strings for all pages of the document
 :)
declare %private function sitemap:get-document-pages($appBase as xs:string, $baseUri as xs:string, $doc as map(*)) as xs:string* {
    sitemap:get-document-pages-recursive($appBase, $baseUri, $doc, (), ())
};

(:~
 : Recursively get all pages for a document by following nextId/next pagination.
 :
 : @param $appBase The base URI for API calls
 : @param $baseUri The base URI to use in sitemap URLs
 : @param $doc The document map containing path and other metadata
 : @param $id Optional id parameter for pagination
 : @param $root Optional root parameter for pagination
 : @return sequence of URL strings for all pages of the document
 :)
declare %private function sitemap:get-document-pages-recursive(
    $appBase as xs:string,
    $baseUri as xs:string, 
    $doc as map(*), 
    $id as xs:string?,
    $root as xs:string?
) as xs:string* {
    let $path := $doc?path
    let $paramList := 
        (
            "serialize=xml",
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
                    $baseUri || "/" || $path || "?id=" || encode-for-uri($json?id)
                else if (map:contains($json, "rootNode") and $json?rootNode != "") then
                    $baseUri || "/" || $path || "?root=" || encode-for-uri($json?rootNode)
                else
                    $baseUri || "/" || $path
            let $nextId := if (map:contains($json, "nextId") and $json?nextId != "") then $json?nextId else ()
            let $next := if (map:contains($json, "next") and $json?next != "") then $json?next else ()
            return (
                $currentUrl,
                if ($nextId) then
                    sitemap:get-document-pages-recursive($appBase, $baseUri, $doc, $nextId, ())
                else if ($next) then
                    sitemap:get-document-pages-recursive($appBase, $baseUri, $doc, (), $next)
                else
                    ()
            )
        else
            (: If the request fails, just return the base path :)
            ($baseUri || "/" || $path)
};
