xquery version "3.1";

module namespace iapi="http://teipublisher.com/api/info";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace router="http://e-editiones.org/roaster";
import module namespace errors = "http://e-editiones.org/roaster/errors";

declare function iapi:version($request as map(*)) {
    map {
        "api": $request?spec?info?version,
        "app": map {
            "name": $config:expath-descriptor/@abbrev/string(),
            "version": $config:expath-descriptor/@version/string()
        },
        "engine": map {
            "name": system:get-product-name(),
            "version": system:get-version()
        }
    }
};

declare function iapi:list-templates($request as map(*)) {
    array {
        for $html in collection($config:app-root || "/templates/pages")/*
        let $description := $html//meta[@name="description"]/@content/string()
        return
            map {
                "name": util:document-name($html),
                "title": $description
            }
    }
};

declare function iapi:source($request as map(*)) {
    let $path := xmldb:decode($request?parameters?path)
    return
        if ($path) then
            let $path := xmldb:encode-uri($config:app-root || "/" || $path)
            let $filename := replace($path, "^.*/([^/]+)$", "$1")
            let $mime := xmldb:get-mime-type($path)[1]
            return
                if (util:binary-doc-available($path)) then
                    response:stream-binary(util:binary-doc($path), $mime, $filename)
                else if (doc-available($path)) then
                    router:response(200, $mime, doc($path))
                else
                    error($errors:NOT_FOUND, "File " || $path || " not found")
        else
            error($errors:BAD_REQUEST, "No path specified")
};