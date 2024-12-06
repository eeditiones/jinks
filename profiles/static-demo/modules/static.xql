xquery version "3.1";

import module namespace static="http://tei-publisher.com/jinks/static" at "xmldb:exist:///db/apps/jinks/modules/static.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
let $context := static:prepare($jsonConfig)
return
    static:generate-from-config($context)