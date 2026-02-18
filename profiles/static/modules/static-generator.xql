(:~
 : Defines the endpoint which generates a static version of the site.
 :
 : By default gets its instructions from the `static` section in `config.json`.
 : Overwrite this file in your profile to add further non-default processing steps 
 : (see register profile).
 :
 : To activate the endpoint, you must select the `static` feature as well in jinks.
 :)
xquery version "3.1";

module namespace sg="http://tei-publisher.com/static/generate";

import module namespace static="http://tei-publisher.com/jinks/static" at "static.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace path="http://tei-publisher.com/jinks/path";

declare function sg:generate-static($request as map(*)) {
    array {
        let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
        let $context := static:prepare($jsonConfig)
        return
            static:generate-from-config($context)
    }
};

declare function sg:generate-static-zip($request as map(*)) {
    let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
    let $staticTarget := 
        if ($jsonConfig?static?target) then
            $jsonConfig?static?target
        else
            "output"
    let $path := path:resolve-path($config:app-root, $staticTarget)
    let $_ := util:log("INFO", ("Generating zip for static files in: ", $path))
    let $entries := sg:zip-entries($path)
    let $xar := compression:zip($entries, true())
    let $name := $jsonConfig?pkg?abbrev
    return
        response:stream-binary($xar, "media-type=application/zip", $name || ".static.zip")
};

declare %private function sg:zip-entries($app-collection as xs:string) {
    (: compression:zip doesn't seem to store empty collections, so we'll scan for only resources :)
    sg:scan(xs:anyURI($app-collection), function($collection as xs:anyURI, $resource as xs:anyURI?) {
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

declare %private function sg:scan($root as xs:anyURI, $func as function(xs:anyURI, xs:anyURI?) as item()*) {
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
            sg:scan(xs:anyURI($root || "/" || $child), $func)
    else
        ()
};