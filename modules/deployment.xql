xquery version "3.1";

module namespace deploy = "http://exist-db.org/xquery/deployment";

declare namespace expath="http://expath.org/ns/pkg";

import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";

declare variable $deploy:ERROR_PERMISSION := xs:QName("deploy:permission-denied");

declare %private function deploy:scan-resources($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) {
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
            deploy:scan-resources(xs:anyURI($root || "/" || $child), $func)
    else
        ()
};

declare %private function deploy:zip-entries($app-collection as xs:string) {
    (: compression:zip doesn't seem to store empty collections, so we'll scan for only resources :)
    deploy:scan-resources(xs:anyURI($app-collection), function($collection as xs:anyURI, $resource as xs:anyURI?) {
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

declare function deploy:package($collection as xs:string, $expathConf as element()) {
    let $name := concat($expathConf/@abbrev, "-", $expathConf/@version, ".xar")
    let $entries := deploy:zip-entries($collection)
    let $xar := compression:zip($entries, true())
    return
        try {
            xmldb:store($config:temp_directory, $name, $xar, "application/zip")
        } catch * {
            error($deploy:ERROR_PERMISSION, "Permission denied to store package '" || $name || "'")
        }
};

declare function deploy:deploy($collection as xs:string) {
    let $expathConf := collection($collection)/expath:package
    let $null := deploy:deploy($collection, $expathConf)
    return
        ()
};

declare function deploy:deploy($collection as xs:string, $expathConf as element()) {
    let $pkg := deploy:package($collection, $expathConf)
    let $name := $expathConf/@name/string()
    return (
        deploy:undeploy($name),
        repo:install-and-deploy-from-db($pkg),
        xmldb:remove($collection)
    )
};

declare function deploy:undeploy($id as xs:string) {
    if (index-of(repo:list(), $id)) then (
        repo:undeploy($id),
        repo:remove($id)
    ) else
        ()
};