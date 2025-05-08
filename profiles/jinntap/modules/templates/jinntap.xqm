xquery version "3.1";

module namespace jt="http://teipublisher.com/ns/templates/jinntap";

import module namespace jwt="http://existsolutions.com/ns/jwt";

declare variable $jt:JWT_SECRET := head((util:system-property("jwt.secret"), "your-secret-key"));
declare variable $jt:JWT_LIFETIME := 30*24*60*60;

declare function jt:jwt-token() {
    let $jwt := jwt:instance($jt:JWT_SECRET, $jt:JWT_LIFETIME)
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