xquery version "3.1";

(:~
 : Stream a file from an installed library package. Profile documentation requests
 : such as /profiles/psalmy/doc/README.md are not stored inside the Jinks app, and a
 : library has no public collection URL. The package repository is the access path.
 :)
import module namespace repo="http://exist-db.org/xquery/repo";

declare function local:mime($path as xs:string) as xs:string {
    if (ends-with($path, ".md")) then "text/markdown"
    else if (ends-with($path, ".json")) then "application/json"
    else if (ends-with($path, ".css")) then "text/css"
    else if (ends-with($path, ".js")) then "text/javascript"
    else if (ends-with($path, ".svg")) then "image/svg+xml"
    else if (ends-with($path, ".png")) then "image/png"
    else if (ends-with($path, ".woff2")) then "font/woff2"
    else if (ends-with($path, ".ttf")) then "font/ttf"
    else "application/octet-stream"
};

declare function local:resource($uri as xs:string, $path as xs:string) as xs:base64Binary? {
    try {
        repo:get-resource($uri, $path)
    } catch * {
        ()
    }
};

let $requestPath := request:get-parameter("path", ())
let $name := replace($requestPath, "^/profiles/([^/]+)/.*$", "$1")
let $resource := "profiles/" || $name || substring-after($requestPath, "/profiles/" || $name)
let $pkg :=
    head(
        for $uri in repo:list()
        where exists(local:resource($uri, "profiles/" || $name || "/config.json"))
        return $uri
    )
let $binary := if ($pkg) then local:resource($pkg, $resource) else ()
return
    if (empty($binary)) then (
        response:set-status-code(404),
        response:set-header("Content-Type", "text/plain"),
        "Resource " || $resource || " not found in an installed package"
    ) else
        response:stream-binary($binary, local:mime($resource), replace($resource, "^.*/", ""))
