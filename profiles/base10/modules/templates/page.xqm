xquery version "3.1";

module namespace page="http://teipublisher.com/ns/templates/page";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace jwt="http://existsolutions.com/ns/jwt";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $page:JWT_SECRET := head((util:system-property("jwt.secret"), "your-secret-key"));
declare variable $page:JWT_LIFETIME := 30*24*60*60;

declare variable $page:EXIDE :=
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");

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

declare function page:jwt-token($context as map(*)) {
    let $jwt := jwt:instance($page:JWT_SECRET, $page:JWT_LIFETIME)
    let $real-u := sm:id()/sm:id/sm:real
    let $payload := map {
        "name": $real-u/sm:username/text(),
        "groups": array { 
            $real-u//sm:group/text()
        }
    }
    return
        $jwt?create($payload)
};