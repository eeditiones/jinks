xquery version "3.1";

module namespace action="http://teipublisher.com/api/actions";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";

declare function action:reindex($request as map(*)) {
    util:log("INFO", ("Reindexing ", $config:data-root)),
    xmldb:reindex($config:data-root)
};