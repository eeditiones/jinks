xquery version "3.1";

module namespace action="http://teipublisher.org/jinks/api/actions";

import module namespace errors = "http://e-editiones.org/roaster/errors";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace expath="http://expath.org/ns/pkg";

declare option output:method "json";
declare option output:media-type "application/json";
declare option output:indent "no";

declare function action:file-sync($request as map(*)) {
    let $root := $request?parameters?root
    let $target := $request?parameters?target
    let $sync :=
        try {
            file:sync($root, $target, map { 
                "indent": false()
            })
        } catch * {
            error($errors:BAD_REQUEST, "Error syncing files: " || $err:description)
        }
    return 
        array {
            map {
                "type": "action:file-sync",
                "message": count($sync//file:update) || " files synced to " || $target
            },
            for $file in $sync/file:sync/*
            let $collection := substring-after($file/@collection, $root || "/")
            let $path :=  string-join(($collection, $file/@name/string()), "/")
            return
                map {
                    "type": local-name($file),
                    "message": $path
                }
        }
};

declare function action:reindex($request as map(*)) {
    let $root := $request?parameters?root
    return (
        let $_ := xmldb:copy-resource($root, "collection.xconf", "/db/system/config/" || $root, "collection.xconf")
        return
            map {
                "type": "action:reindex",
                "message": "collection.xconf copied to /db/system/config/" || $root
            },
        let $_ := xmldb:reindex($root)
        return
            map {
                "type": "action:reindex",
                "message": $root || " reindexed"
            }
    )
};

declare function action:download-app($request as map(*)) {
    let $root := $request?parameters?root
    let $expathConf := doc($root || "/expath-pkg.xml")/expath:package
    let $entries := action:zip-entries($root)
    let $xar := compression:zip($entries, true())
    let $name := $expathConf/@abbrev
    return
        response:stream-binary($xar, "media-type=application/zip", $name || ".xar")
};

declare %private function action:zip-entries($app-collection as xs:string) {
    (: compression:zip doesn't seem to store empty collections, so we'll scan for only resources :)
    action:scan(xs:anyURI($app-collection), function($collection as xs:anyURI, $resource as xs:anyURI?) {
        if (exists($resource)) then
            let $relative-path := substring-after($resource, $app-collection || "/")
            return
                if (starts-with($relative-path, "transform/")) then
                    ()
                else if (util:binary-doc-available($resource)) then
                    <entry name="{$relative-path}" type="uri">{$resource}</entry>
                else
                    <entry name="{$relative-path}" type="text">
                    {
                        serialize(doc($resource), map { "indent": false() })
                    }
                    </entry>
        else
            ()
    })
};

declare %private function action:scan($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) {
    $func($root, ()),
    if (sm:has-access($root, "rx")) then
        for $child in xmldb:get-child-resources($root)
        return
            $func($root, xs:anyURI($root || "/" || $child))
    else
        (),
    if (sm:has-access($root, "rx")) then
        for $child in xmldb:get-child-collections($root)
        return
            action:scan(xs:anyURI($root || "/" || $child), $func)
    else
        ()
};