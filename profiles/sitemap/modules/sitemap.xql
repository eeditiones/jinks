xquery version "3.1";

module namespace sitemap="http://tei-publisher.org/api/sitemap";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "../pages.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "../query.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../util.xql";
import module namespace router="http://e-editiones.org/roaster";

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
            (: Substitute the [[ $baseUri ]] placeholder with a plain linear
             : tokenize/join rather than the templating engine: a sitemap can hold
             : thousands of <url> siblings, and tmpl:process recurses over them,
             : overflowing the stack. tokenize scans once; string-join inserts the
             : base URI literally (no replacement-string interpretation). :)
            let $template := serialize(doc($sitemapPath))
            let $expanded := string-join(tokenize($template, '\[\[ \$baseUri \]\]'), $baseUri)
            return
                (: Return a parsed node, not the string: router:response serializes a
                 : node as XML, whereas a string body would be emitted as escaped text. :)
                router:response(200, "application/xml", parse-xml($expanded))
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
    let $sitemap := sitemap:generate($config)
    let $stored := xmldb:store($config:app-root, "sitemap.xml", $sitemap, "application/xml")
    return [
        map {
            "type": "actions:sitemap",
            "message": "Sitemap generated in " || $stored
        }
    ]
};

(:~
 : Generate a sitemap.xml by crawling the application in-process. URLs are stored
 : with a [[ $baseUri ]] placeholder that is substituted at serve time by
 : sitemap:get-sitemap.
 :
 : @return sitemap.xml document
 :)
declare %private function sitemap:generate($config as map(*)) as document-node() {
    let $urls := sitemap:crawl()
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
 : Crawl the application and collect all document/page URLs without any HTTP
 : round-trips. The document list is obtained the same way the /api/documents
 : endpoint does (query:query-metadata), and each document is paginated through
 : in-process using the same primitives as /api/parts (dapi:get-fragment with
 : content=none): pages:load-xml to load a fragment and $config:next-page to
 : advance, collecting the stable xml:id (or node id as fallback) of each page.
 :
 : @return sequence of relative URL strings (without base URI)
 :)
declare %private function sitemap:crawl() as xs:string* {
    let $works := query:query-metadata((), "div", (), $config:sort-default)?all
    return
        distinct-values(
            for $doc in $works
            return
                sitemap:document-urls($doc)
        )
};

(:~
 : Collect the URLs for a single document: one per page/division. The view is
 : taken from the document's processing instruction (passing () as the view to
 : tpu:parse-pi so the PI value is honored). A single-view document has exactly
 : one URL.
 :
 : @param $doc a document node returned by query:query-metadata
 : @return sequence of relative URL strings for the document
 :)
declare %private function sitemap:document-urls($doc as node()) as xs:string* {
    let $path := config:get-identifier($doc)
    let $documents := config:get-document($path)
    let $config := tpu:parse-pi(root($documents[1]), (), $config:default-odd)
    let $view := $config?view
    return
        if (empty($documents)) then
            ()
        else if ($view = "single") then
            $path
        else
            sitemap:page-urls($documents, $view, $path, ())
};

(:~
 : Recursively page through a document, mirroring the next/nextId pagination the
 : old crawler followed via /api/parts. For each fragment it emits the relative
 : URL and, if there is a following fragment, recurses using that fragment's node
 : id as the root.
 :
 : @param $documents the loaded document node(s)
 : @param $view the view to use (div or page)
 : @param $path the document identifier used to build URLs
 : @param $root optional eXist node id identifying the fragment to load
 : @return sequence of relative URL strings
 :)
declare %private function sitemap:page-urls(
    $documents as node()*,
    $view as xs:string,
    $path as xs:string,
    $root as xs:string?
) as xs:string* {
    let $fragment := pages:load-xml($documents, $view, $root, $path)
    let $config := $fragment?config
    let $data := $fragment?data
    return
        if (empty($data)) then
            (: no navigable fragment: fall back to the bare document URL :)
            if (empty($root)) then $path else ()
        else
            let $content := pages:get-content($config, $data)
            let $id := $content/@xml:id/string()
            let $currentUrl :=
                if (string-length(normalize-space($id)) gt 0) then
                    $path || "?id=" || encode-for-uri($id)
                else
                    $path || "?root=" || util:node-id($data[1])
            let $next := $config:next-page($config, $data, $view)
            return (
                $currentUrl,
                if ($next) then
                    sitemap:page-urls($documents, $view, $path, util:node-id($next))
                else
                    ()
            )
};
