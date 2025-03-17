xquery version "3.1";

module namespace page="http://teipublisher.com/ns/templates/page";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

declare function page:system() {
    map {
        "publisher": $config:expath-descriptor/@version/string(),
        "api": json-doc($config:app-root || "/modules/lib/api.json")?info?version
    }
};

declare function page:parameter($context as map(*), $name as xs:string) {
    page:parameter($context, $name, ())
};

(:~
 : Get a parameter from the request. Return the default value if the parameter
 : is not present.
 :)
declare function page:parameter($context as map(*), $name as xs:string, $default as item()*) {
    let $reqParam := head(($context?request?parameters?($name), request:get-parameter($name, ())))
    return
        if (exists($reqParam)) then
            $reqParam
        else
            $default
};