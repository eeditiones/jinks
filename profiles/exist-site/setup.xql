xquery version "3.1";

module namespace site="https://exist-db.org/jinks/exist-site/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";

declare namespace generator="http://tei-publisher.com/library/generator";

(:~
 : Copy profile files to the target app using default behavior.
 :)
declare
    %generator:write
function site:setup($context as map(*)) {
    cpy:copy-collection($context)
};

(:~
 : After all files are written, re-store runtime templates as binary
 : from the original profile source. The default copy stores .html
 : files as XML, which corrupts Jinks template directives.
 :)
declare
    %generator:after-write
function site:fix-templates($context as map(*), $target as xs:string) {
    let $source := path:resolve-path($context?source, "templates")
    let $tmpl-coll := $target || "/templates"
    return
        if (xmldb:collection-available($source)) then
            for $resource in xmldb:get-child-resources($source)
            where ends-with($resource, ".html")
            let $source-path := $source || "/" || $resource
            where util:binary-doc-available($source-path)
            let $content := util:binary-doc($source-path)
            let $_ :=
                if (doc-available($tmpl-coll || "/" || $resource)) then
                    xmldb:remove($tmpl-coll, $resource)
                else ()
            return (
                path:mkcol($context, "templates"),
                xmldb:store($tmpl-coll, $resource, $content, "application/octet-stream")
            )
        else ()
};
