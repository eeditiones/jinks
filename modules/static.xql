xquery version "3.1";

module namespace static="http://tei-publisher.com/jinks/static";

import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "cpy.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";

declare variable $static:ERROR_PART_LOAD_FAILED := QName("http://tei-publisher.com/jinks/static", "part-load-failed");
declare variable $static:ERROR_LOAD_FAILED := QName("http://tei-publisher.com/jinks/static", "load-failed");

(:~
 : Process the document at the given path and break it up into pages, storing each page as a separate file.
 : The function calls the `/api/parts/{path}/json` endpoint of the application to retrieve the pages. This means
 : the actual pagination algorithm is determined by the application.
 :)
declare function static:paginate($context as map(*), $parts as map(*)+, $template as xs:string,
    $targetPathGen as function(*)) {
    static:next-page($context, $parts, (), $template, 1, $targetPathGen)
};

declare %private function static:next-page($context as map(*), $parts as map(*)+, 
    $root as xs:string?, $template as xs:string,
    $count as xs:int, $targetPathGen as function(*)) {
    let $json := map:merge((
        for $part in $parts
        let $data := static:load-part($context, $part?path, map:merge((map { "root": $root }, $part)))
        return
            map:entry(head(($part?id, "default")), $data)
    ))
    let $templateContent := cpy:resource-as-string($context, $template)
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
        ),
        if ($json?default?next) then
            static:next-page($context, $parts, $json?default?next, $template, $count + 1, $targetPathGen)
        else 
            ()
    )
    return
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
    let $request := 
        <http:request method="GET" 
            href="{$context?base-uri}/api/parts/{encode-for-uri($path)}/json?{static:params-to-query($mergedParams)}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $data := util:binary-to-string(xs:base64Binary($response[2]))
            return
                parse-json($data)
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

declare function static:load($context as map(*), $url as xs:string, $target as xs:string) {
    let $request := 
        <http:request method="GET" href="{$url}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $targetPath := path:resolve-path($context?target, $target)
            return
                xmldb:store(path:parent($targetPath), path:basename($targetPath), $response[2])[2]
        else
            error($static:ERROR_LOAD_FAILED, $response[1]/@status)
};