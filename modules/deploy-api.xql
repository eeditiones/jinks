declare namespace dep="http://tei-publisher.com/library/generator/deploy-api";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace path="http://tei-publisher.com/jinks/path" at "./paths.xql";

import module namespace deploy = "http://exist-db.org/xquery/deployment" at "deployment.xql";
import module namespace generator="http://tei-publisher.com/library/generator" at "generator.xql";
import module namespace config="https://tei-publisher.com/generator/xquery/config" at "config.xql";
import module namespace action="http://teipublisher.org/jinks/api/actions" at "actions.xql";
import module namespace errors = "http://e-editiones.org/roaster/errors";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";
declare option output:indent "no";

(:~
 : Deploy a prepared profile
 : 
 : Neesd to called for new profiles, to actually get them deployed as applications 
 :
 : @param $request A map shaped like {"parameters": {"profile": "$profile_name"}}
 :)
declare function dep:deploy($request as map(*)) {
    let $profile := $request?parameters?profile
    let $profile-temp-location := $config:temp_directory || "/" || $profile

    return
        if (not(xmldb:collection-available($profile-temp-location))) then
            error(
                $errors:NOT_FOUND,
                "The profile " ||
                    $profile ||
                    " is not prepared yet. Call the /api/generator endpoint first.")
        else
            deploy:deploy($profile-temp-location)
};

declare function dep:run-action($request as map(*)) {
    let $target := path:get-package-target($request?parameters?id)
    return
        if (empty($target)) then
            error(
                $errors:NOT_FOUND,
                "Package with URI " || $request?parameters?id || " not found"
            )
        else
            generator:run-action($target, $request?parameters?action)
};

let $lookup := function($name as xs:string) {
    try {
        function-lookup(xs:QName($name), 1)
    } catch * {
        ()
    }
}
let $resp := roaster:route("modules/deploy-api.json", $lookup)
return
    $resp