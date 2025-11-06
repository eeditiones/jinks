xquery version "3.1";

declare namespace api="https://tei-publisher.com/xquery/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace auth="http://e-editiones.org/roaster/auth";
import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace dapi="http://teipublisher.com/api/documents" at "api/document.xqm";
import module namespace capi="http://teipublisher.com/api/collection" at "api/collection.xqm";
import module namespace sapi="http://teipublisher.com/api/search" at "api/search.xqm";
import module namespace dts="http://teipublisher.com/api/dts" at "api/dts.xqm";
import module namespace iapi="http://teipublisher.com/api/info" at "api/info.xqm";
import module namespace vapi="http://teipublisher.com/api/view" at "api/view.xqm";
import module namespace iiif="https://e-editiones.org/api/iiif" at "api/iiif.xqm";
import module namespace nlp="http://teipublisher.com/api/nlp" at "api/nlp.xqm";
import module namespace rapi="http://teipublisher.com/api/registers" at "../registers.xqm";
import module namespace custom="http://teipublisher.com/api/custom" at "../custom-api.xqm";
import module namespace action="http://teipublisher.com/api/actions" at "api/actions.xqm";
import module namespace deploy="https://teipublisher.org/api/deploy" at "api/deploy.xqm";

[% for $module in $context?api?* %]
[% if $module?path %]
import module namespace [[ $module?prefix ]]="[[ $module?id ]]" at "../[[ $module?path ]]";
[% endif %]
[% endfor %]

declare option output:indent "no";

let $lookup := function($name as xs:string) {
    try {
        let $cfun := custom:lookup($name, 1)
        return
            if (empty($cfun)) then
                function-lookup(xs:QName($name), 1)
            else
                $cfun
    } catch * {
        ()
    }
}
let $resp := roaster:route(
    (
        [% for $module in reverse($context?api?*) %]
        [% if $module?spec %]
        "modules/[[ $module?spec ]]",
        [% endif %]
        [% endfor %]
        "modules/custom-api.json",
        "modules/lib/api.json"
    ), $lookup)
return
    $resp