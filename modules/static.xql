xquery version "3.1";

module namespace static="http://tei-publisher.com/jinks/static";

import module namespace tmpl="http://e-editiones.org/xquery/templates";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "cpy.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace path="http://tei-publisher.com/jinks/path" at "paths.xql";

declare function static:paginate($context as map(*), $path as xs:string, $template as xs:string,
    $targetPathGen as function(*)) {
    static:next-page($context, $path, (), $template, 1, $targetPathGen)
};

declare %private function static:next-page($context as map(*), $path as xs:string, 
    $root as xs:string?, $template as xs:string,
    $count as xs:int, $targetPathGen as function(*)) {
    let $params := ``[root=`{$root}`&amp;view=`{$context?defaults?view}`]``
    let $request := 
        <http:request method="GET" 
            href="{$context?base-uri}/api/parts/{encode-for-uri($path)}/json?serialize=xml&amp;{$params}"/>
    let $response := http:send-request($request)
    return
        if ($response[1]/@status = 200) then
            let $data := util:binary-to-string(xs:base64Binary($response[2]))
            let $json := parse-json($data)
            let $templateContent := cpy:resource-as-string($context, $template)
            let $output :=
                tmpl:process(
                    $templateContent, 
                    map:merge((
                        $context, 
                        map {
                            "pagination": map {
                                "data": $json,
                                "page": $count
                            }
                        }
                    )), 
                    true(),
                    cpy:resource-as-string($context, ?)
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
                if ($json?next) then
                    static:next-page($context, $path, $json?next, $template, $count + 1, $targetPathGen)
                else 
                    ()
            )
            return
                ()
        else
            util:log("WARN", ($response))
};