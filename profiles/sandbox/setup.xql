xquery version "3.1";

(:~
 : Setup script for the sandbox feature profile.
 : Parses markdown files and stores them as XML so they can be
 : indexed and browsed by TEI Publisher.
 :)
module namespace setup="https://exist-db.org/apps/sandbox/setup";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace path="http://tei-publisher.com/jinks/path";
import module namespace md="http://exist-db.org/xquery/markdown";

declare namespace generator="http://tei-publisher.com/library/generator";
declare namespace mdns="http://exist-db.org/xquery/markdown";

(:~
 : Copy profile files as usual.
 :)
declare
    %generator:write
function setup:setup($context as map(*)) {
    cpy:copy-collection($context)
};

(:~
 : After deployment: parse all markdown files in the content collection
 : and store parsed XML versions for indexing.
 :)
declare
    %generator:after-write
function setup:after-write($context as map(*), $target as xs:string) {
    let $content-root := $target || "/content"
    return
        if (xmldb:collection-available($content-root)) then
            setup:parse-markdown-collection($content-root)
        else
            ()
};

(:~
 : Recursively parse .md files and store as .md.xml alongside the binary.
 :)
declare %private function setup:parse-markdown-collection($collection as xs:string) {
    (
        for $resource in xmldb:get-child-resources($collection)
        where ends-with($resource, ".md") and util:binary-doc-available($collection || "/" || $resource)
        let $source := util:binary-to-string(util:binary-doc($collection || "/" || $resource))
        let $parsed := md:parse($source)
        let $xml-name := $resource || ".xml"
        return
            xmldb:store($collection, $xml-name, $parsed, "application/xml"),
        for $child in xmldb:get-child-collections($collection)
        where $child != "data"
        return
            setup:parse-markdown-collection($collection || "/" || $child)
    )
};
