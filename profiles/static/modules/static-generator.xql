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

declare function sg:generate-static($request as map(*)) {
    array {
        let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
        let $context := static:prepare($jsonConfig)
        return
            static:generate-from-config($context)
    }
};