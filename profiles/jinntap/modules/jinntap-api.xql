xquery version "3.1";

module namespace jtapi="http://e-editiones.org/api/jinntap";

import module namespace router="http://e-editiones.org/roaster";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace repo="http://exist-db.org/xquery/repo";

declare variable $jtapi:IMAGE-TYPES := (
    "image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/tiff"
);

declare variable $jtapi:repoxml := (
    let $uri := doc($config:app-root || "/expath-pkg.xml")/*/@name
    let $repo := util:binary-to-string(repo:get-resource($uri, "repo.xml"))
    return
        parse-xml($repo)
);

declare %private function jtapi:mkcol-recursive($collection as xs:string, $components as xs:string*) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            if (not(xmldb:collection-available($collection || "/" || $components[1]))) then
                let $created := xmldb:create-collection($collection, $components[1])
                return (
                    sm:chown(xs:anyURI($created), $jtapi:repoxml//repo:permissions/@user),
                    sm:chgrp(xs:anyURI($created), $jtapi:repoxml//repo:permissions/@group),
                    sm:chmod(
                        xs:anyURI($created),
                        replace($jtapi:repoxml//repo:permissions/@mode, "(..).(..).(..).", "$1x$2x$3x")
                    )
                )
            else
                (),
            jtapi:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

declare %private function jtapi:mkcol($collection as xs:string, $path as xs:string) {
    if ($path = "" or $path = "/") then
        ()
    else
        jtapi:mkcol-recursive($collection, tokenize($path, "/+")[. ne ""])
};

declare %private function jtapi:collection-uri($rel as xs:string) as xs:string {
    let $rel := replace($rel, "^/+|/+$", "")
    return
        if ($rel = "") then
            $config:data-default
        else
            $config:data-default || "/" || $rel
};

declare %private function jtapi:asset-file-uri($id as xs:string) as xs:string {
    let $id := replace($id, "^/+", "")
    return
        xmldb:encode-uri(
            if ($id = "") then
                $config:data-default
            else
                $config:data-default || "/" || $id
        )
};

declare %private function jtapi:resource-size($collection-uri as xs:string, $name as xs:string) as xs:integer {
    try {
        xmldb:size($collection-uri, $name)
    } catch * {
        0
    }
};

declare %private function jtapi:resource-updated($collection-uri as xs:string, $name as xs:string) as xs:double {
    let $lm := xmldb:last-modified($collection-uri, $name)
    return
        if (exists($lm)) then
            (xs:dateTime($lm) - xs:dateTime("1970-01-01T00:00:00Z")) div xs:dayTimeDuration("PT0.001S")
        else
            0
};

declare %private function jtapi:asset-meta($collection-uri as xs:string, $name as xs:string) as map(*)? {
    let $path := $collection-uri || "/" || $name
    let $mime := xmldb:get-mime-type($path)
    return
        if (util:binary-doc-available($path) and $mime = $jtapi:IMAGE-TYPES) then
            map {
                "path": $name,
                "mimeType": $mime,
                "size": jtapi:resource-size($collection-uri, $name),
                "updatedAt": jtapi:resource-updated($collection-uri, $name)
            }
        else
            ()
};

(:~
 : GET /api/jinntap/assets?collection=…
 : `collection` is relative to $config:data-default.
 :)
declare function jtapi:list-assets($request as map(*)) {
    let $collection := replace(xmldb:decode(($request?parameters?collection, "")[1]), "^/+|/+$", "")
    let $uri := jtapi:collection-uri($collection)
    return
        if (not(xmldb:collection-available($uri))) then
            array {}
        else
            array {
                for $name in xmldb:get-child-resources($uri)
                let $meta := jtapi:asset-meta($uri, $name)
                where exists($meta)
                order by $meta?updatedAt descending
                return
                    $meta
            }
};

(:~
 : POST /api/jinntap/assets?collection=…  multipart files[]
 : `collection` is relative to $config:data-default.
 :)
declare function jtapi:upload-assets($request as map(*)) {
    let $collection := replace(xmldb:decode(($request?parameters?collection, "")[1]), "^/+|/+$", "")
    let $_ := jtapi:mkcol($config:data-default, $collection)
    let $uri := jtapi:collection-uri($collection)
    let $names := request:get-uploaded-file-name("files[]")
    let $data := request:get-uploaded-file-data("files[]")
    return
        if (empty($names)) then
            error($errors:BAD_REQUEST, "No files uploaded")
        else
            array {
                for-each-pair($names, $data, function ($name, $bin) {
                    let $safe := replace($name, "^.*/", "")
                    let $stored := xmldb:store($uri, xmldb:encode($safe), $bin)
                    let $mime := xmldb:get-mime-type($stored)
                    return
                        map {
                            "path": $safe,
                            "mimeType": $mime,
                            "size": jtapi:resource-size($uri, xmldb:encode($safe)),
                            "updatedAt": jtapi:resource-updated($uri, xmldb:encode($safe))
                        }
                })
            }
};

(:~
 : GET /api/jinntap/assets/{id}
 : `{id}` is relative to $config:data-default (e.g. photo.png or sub/photo.png).
 :)
declare function jtapi:get-asset($request as map(*)) {
    let $id := xmldb:decode($request?parameters?id)
    let $path := jtapi:asset-file-uri($id)
    let $filename := replace($id, "^.*/([^/]+)$", "$1")
    return
        if (util:binary-doc-available($path)) then
            let $mime := xmldb:get-mime-type($path)
            return
                response:stream-binary(util:binary-doc($path), $mime, $filename)
        else
            error($errors:NOT_FOUND, "Asset " || $id || " not found")
};

(:~
 : PUT /api/jinntap/assets/{id}
 : `{id}` is relative to $config:data-default.
 :)
declare function jtapi:put-asset($request as map(*)) {
    let $id := xmldb:decode($request?parameters?id)
    let $parts := tokenize($id, "/")[. ne ""]
    let $name := $parts[last()]
    let $collection := string-join($parts[position() lt last()], "/")
    let $_ := jtapi:mkcol($config:data-default, $collection)
    let $uri := jtapi:collection-uri($collection)
    let $body :=
        if (exists($request?body)) then
            $request?body
        else
            request:get-data()
    let $stored := xmldb:store($uri, xmldb:encode($name), $body)
    let $mime := xmldb:get-mime-type($stored)
    return
        router:response(
            200,
            "application/json",
            map {
                "path": $name,
                "mimeType": $mime,
                "size": jtapi:resource-size($uri, xmldb:encode($name)),
                "updatedAt": jtapi:resource-updated($uri, xmldb:encode($name))
            }
        )
};

(:~
 : DELETE /api/jinntap/assets/{id}
 : `{id}` is relative to $config:data-default.
 :)
declare function jtapi:delete-asset($request as map(*)) {
    let $id := xmldb:decode($request?parameters?id)
    let $parts := tokenize($id, "/")[. ne ""]
    let $name := $parts[last()]
    let $collection := string-join($parts[position() lt last()], "/")
    let $uri := jtapi:collection-uri($collection)
    let $path := $uri || "/" || xmldb:encode($name)
    return
        if (util:binary-doc-available($path)) then (
            xmldb:remove($uri, xmldb:encode($name)),
            router:response(204, "Asset deleted")
        ) else
            error($errors:NOT_FOUND, "Asset " || $id || " not found")
};
