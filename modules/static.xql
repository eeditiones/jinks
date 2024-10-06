xquery version "3.1";

module namespace static="http://tei-publisher.com/jinks/static";

import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "cpy.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";

declare namespace xhtml="http://www.w3.org/1999/xhtml";

declare variable $static:ERROR_PART_LOAD_FAILED := QName("http://tei-publisher.com/jinks/static", "part-load-failed");
declare variable $static:ERROR_LOAD_FAILED := QName("http://tei-publisher.com/jinks/static", "load-failed");

declare function static:preload-view($context as map(*), $config as map(*)) {
    let $path := path:mkcol($context, $config?path)
    let $entries := static:preload-view-next($context, $config, (), $path, 1)
    return
        static:save-index($path || "/index.json", $entries)
};

declare %private function static:preload-view-next($context as map(*), $config as map(*), $root as xs:string?, 
    $outputPath as xs:string, $counter as xs:int) {
    let $json := static:load-part($context, $config?path, map:merge((map { "root": $root }, $config)))
    let $outputFile := $config?id || "-" || $counter || ".json"
    let $stored := xmldb:store(
        $outputPath, 
        $outputFile, 
        serialize($json, map { "method": "json", "indent": true() }), 
        "application/json"
    )
    return
        if ($json?next) then (
            static:preload-view-next($context, $config, $json?next, $outputPath, $counter + 1),
            map:entry($json?key, $outputFile)
        ) else 
            ()
};

declare function static:save-index($path as xs:string, $entries as map(*)*) {
    let $oldMap :=
        if (util:binary-doc-available($path)) then
            parse-json(util:binary-doc($path))
        else
            ()
    let $newMap := map:merge(($oldMap, $entries))
    return
        xmldb:store(
            path:parent($path), 
            path:basename($path), 
            serialize($newMap, map { "method": "json", "indent": true() }), 
            "application/json"
        )
};

(:~
 : Paginate a document outputting HTML for each page.
 :
 : Process the document at the given path and break it up into pages, storing each page as a separate index.html file
 : in a directory. The output directory path is determined by the string returned by $targetPathGen.
 :
 : The function calls the `/api/parts/{path}/json` endpoint of the application to retrieve the pages. This means
 : the actual pagination algorithm is determined by the application.
 : @param $context The context map passed to templating when expanding the template
 : @param $config An array of part configurations 
 : @param $template The path to the template to use for rendering the pages
 : @param $targetPathGen A function that generates the target path for each page. The function is passed the context
 : and the page number as arguments.
 :)
declare function static:paginate($context as map(*), $config as array(*), $template as xs:string,
    $targetPathGen as function(*)) {
    static:next-page($context, $config, (), $template, 1, $targetPathGen)
};

(:~
 : Recursively load the parts of the document using the part configuration with id "default" as the main part.
 :)
declare %private function static:next-page($context as map(*), $parts as array(map(*)+), 
    $root as xs:string?, $template as xs:string,
    $count as xs:int, $targetPathGen as function(*)) {
    let $json := map:merge((
        for $part in $parts?*
        let $data := static:load-part(
            $context, 
            $part?path, 
            map:merge((map { "root": $root }, $part))
        )
        return
            map:entry(head(($part?id, "default")), $data)
    ))
    let $templateContent := cpy:resource-as-string($context, $template)?content
    let $output :=
        tmpl:process(
            $templateContent, 
            map:merge((
                $context,
                map {
                    "pagination": map {
                        "page": $count
                    },
                    "parts": $json
                }
            )),
            map {
                "plainText": true(),
                "resolver": cpy:resource-as-string($context, ?)
            }
        )
    let $targetPath := path:resolve-path($context?target, $targetPathGen($context, $count))
    let $nil := (
        util:log("INFO", ("<static> Writing to ", $targetPath)),
        path:mkcol($context, $targetPath),
        xmldb:store(
            $targetPath, 
            "index.html",
            $output,
            "text/html"
        )
    )
    return
        if ($json?default?next) then
            static:next-page($context, $parts, $json?default?next, $template, $count + 1, $targetPathGen)
        else 
            ()
};

declare %private function static:load-part($context as map(*), $path as xs:string, $params as map(*)) {
    let $mergedParams := map:merge((
        map {
            "view": $context?defaults?view,
            "odd": $context?defaults?odd,
            "serialize": "xml"
        },
        for $param in map:keys($params)[not(. = ('path', 'id'))]
        return
            map:entry($param, $params($param))
    ))
    let $urlParams := static:params-to-query($mergedParams)
    let $request := 
        <http:request method="GET" 
            href="{$context?base-uri}/api/parts/{encode-for-uri($path)}/json?{$urlParams}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $data := util:binary-to-string(xs:base64Binary($response[2]))
            return
                map:merge((parse-json($data), map { "key": static:compute-key($mergedParams) }))
        else
            error($static:ERROR_PART_LOAD_FAILED, $response[1]/@status)
};

declare %private function static:params-to-query($params as map(*)) {
    string-join(
        for $key in map:keys($params)
        return
            concat($key, "=", encode-for-uri($params($key))),
        "&amp;"
    )
};

declare function static:compute-key($params as map(*)) {
    string-join(
        for $key in map:keys($params)[not(. = ('serialize'))]
        order by $key
        return
            concat($key, "=", $params($key)),
        "&amp;"
    )
};

(:~
 : Load a resource from a URL and store it in the database.
 :
 : The function sends a GET request to the given URL and returns the content.
 :
 : @param $url The URL of the resource to load
 :)
declare function static:load($url as xs:string) {
    static:load((), $url, ())
};

(:~
 : Load a resource from a URL and store it in the database.
 :
 : The function sends a GET request to the given URL and stores the response in the database. The target path
 : is determined by the $target parameter. If no target is specified, the function will return the response content.
 :
 : @param $context The context map used to resolve relative URLs
 : @param $url The URL of the resource to load
 : @param $target The target path in the database. If relative, it will be resolved against context?target.
 :)
declare function static:load($context as map(*)?, $url as xs:string, $target as xs:string?) {
    let $request := 
        <http:request method="GET" href="{$url}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $contentType := $response[1]/http:header[@name="content-type"]/@value
            return
                if ($target) then
                    let $targetPath := 
                        if (exists($context)) then path:resolve-path($context?target, $target) else $target
                    return
                        xmldb:store(path:parent($targetPath), path:basename($targetPath), $response[2])[2]
                else
                    switch ($contentType)
                        case "application/json" return
                            let $data := util:binary-to-string(xs:base64Binary($response[2]))
                            return
                                parse-json($data)
                        case "text/html" return
                            $response[2]//*:body/node()
                        default return
                            $response[2]
        else
            error($static:ERROR_LOAD_FAILED, "URI: " || $url || ": " || $response[1]/@status)
};

(:~
 : Split the input sequence into chunks of $batchSize items and render each chunk using a template.
 :
 : @param $context The context map passed to the template when expanding the template
 : @param $input The input sequence to split
 : @param $batchSize The maximum size of each batch
 : @param $template The path to the template to use for rendering each batch
 : @param $targetPathGen A function that generates the target path for each batch. The function is passed the context
 : and the batch number as arguments.
 :)
declare function static:split($context as map(*), $input as item()*, $batchSize as xs:int, 
    $template as xs:string, $targetPathGen as function(*)) {
    let $templateContent := cpy:resource-as-string($context, $template)?content
    let $chunks :=
        for $p in 0 to count($input) idiv $batchSize
        return
            array { subsequence($input, $p * $batchSize + 1, $batchSize) }
    for $chunk at $page in $chunks
    let $output :=
        tmpl:process(
            $templateContent, 
            map:merge((
                $context,
                map {
                    "pagination": map {
                        "page": $page,
                        "total": count($chunks)
                    },
                    "content": $chunk?*
                }
            )),
            map {
                "plainText": true(),
                "resolver": cpy:resource-as-string($context, ?)
            }
        )
    let $targetPath := path:resolve-path($context?target, $targetPathGen($context, $page))
    return (
        util:log("INFO", ("<static> Writing to ", $targetPath)),
        path:mkcol($context, $targetPath),
        xmldb:store(
            $targetPath, 
            "index.html",
            $output,
            "text/html"
        )
    )
};

declare function static:index($context as map(*), $input as item()*) {
    let $lines := array {
        for $doc in $input
        let $request := 
            <http:request method="GET" href="{$context?base-uri}/api/static/{encode-for-uri($doc?path)}"/>
        let $response := http:send-request($request)
        return
            if ($response[1]/@status = 200) then
                let $data := util:binary-to-string(xs:base64Binary($response[2]))
                return
                    parse-json($data)
            else
                error($static:ERROR_LOAD_FAILED, "Failed to load index data for " || $doc?path)
    } => serialize(map{ "method": "json", "indent": true() })
    return
        xmldb:store($context?target, "index.json", $lines, "application/json")
};

(:~
 : Redirect the user to a new page. The function generates an HTML page with a meta refresh tag that redirects the
 : user to the new page.
 :
 : @param $context The context map used to resolve relative paths
 : @param $target The target path in the database. If relative, it will be resolved against context?target.
 : @param $redirectTo The URL to redirect to
 :)
declare function static:redirect($context as map(*), $target as xs:string, $redirectTo as xs:string) {
    let $targetPath := path:resolve-path($context?target, $target)
    let $html :=
        <html lang="en">
            <head>
                <meta charset="UTF-8"/>
                <meta http-equiv="refresh" content="0; url={$redirectTo}"/>
                <title>Redirecting...</title>
            </head>
            <body>
                <p>If you are not redirected automatically, follow this <a href="{$redirectTo}">link to the new page</a>.</p>
            </body>
        </html>
    return
        xmldb:store($targetPath, "index.html", $html, "text/html")
};

(:~
 : Fix links in the document by replacing relative links using ids with absolute links pointing to the static HTML.
 :
 : @param $nodes The nodes to process
 : @param $links A map of target elements indexed by their id attribute
 :)
declare %private function static:fix-links($nodes as node()*, $links as map(*)) {
    for $node in $nodes
    return
        typeswitch ($node)
            case document-node() return
                static:fix-links($node/node(), $links)
            case element(a) | element(xhtml:a) return
                if (starts-with($node/@href, "?id=")) then
                    let $resolved := $links(substring-after($node/@href, "?id="))
                    return
                        element { node-name($node) } {
                            $node/@* except $node/@href,
                            attribute href { $resolved },
                            $node/node()
                        }
                else
                    element { node-name($node) } {
                        $node/@*,
                        static:fix-links($node/node(), $links)
                    }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    static:fix-links($node/node(), $links)
                }
            default return
                $node
};

(:~
 : Fix links in the document by replacing relative links using ids with absolute links pointing to the static HTML.
 :)
declare function static:fix-links($context as map(*)) {
    util:log("INFO", ("<static> Fixing links ...")),
    let $base := path:resolve-path($context?target, "")
    let $targets :=
        map:merge(
            for $node in collection($context?target)/html//@id
            return
                map:entry($node, $context?context-path || "/" || document-uri(root($node)) => substring-after($base || "/"))
        )
    for $doc in collection($context?target)
    let $modified := static:fix-links($doc, $targets)
    return
        xmldb:store(util:collection-name($doc), util:document-name($doc), $modified)
};