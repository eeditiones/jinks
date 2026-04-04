xquery version "3.1";

(:~
 : Navigation module for markdown documents.
 : Provides metadata extraction (title, author) for the browse/search UI.
 :)
module namespace nav="http://www.tei-c.org/tei-simple/navigation/markdown";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace md="http://exist-db.org/xquery/markdown";

declare namespace mdns="http://exist-db.org/xquery/markdown";

declare function nav:get-header($config as map(*), $node as element()) {
    ()
};

declare function nav:get-section-for-node($config as map(*), $node as element()) {
    $node
};

declare function nav:get-section($config as map(*), $doc) {
    $doc
};

declare function nav:get-document-title($config as map(*), $root as element()) {
    string(($root//mdns:heading[@level = "1"])[1])
};

declare function nav:get-metadata($config as map(*), $root as element(), $field as xs:string) {
    switch ($field)
        case "title" return
            nav:get-document-title($config, $root)
        case "author" return
            ()
        case "language" return
            "en"
        default return
            ()
};
