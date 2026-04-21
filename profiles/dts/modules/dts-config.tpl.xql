xquery version "3.1";

module namespace dts-config="http://teipublisher.com/api/dts/config";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "navigation.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $dts-config:members := map {
    "id": "default",
    "title": $config:expath-descriptor/expath:title/string(),
    "members": [
        [% for $member in $context?features?dts?member?* %]
        map {
            "id": "[[ $member?id ]]",
            "type": "[[ $member?type ]]",
            "title": "[[ $member?title ]]",
            "path": $config:data-root || "/[[ $member?path ]]"
            [% if exists($member?dublinCore) %]
            ,"dublinCore": [[ serialize($member?dublinCore, map { "method": "adaptive", "indent": true() }) ]]
            [% endif %]
        },
        [% endfor %]
        map {
            "id": "odd",
            "title": "ODD Collection",
            "type": "collection",
            "path": $config:odd-root
        }
    ]
};

declare variable $dts-config:page-size := 10;

declare variable $dts-config:import-collection := $config:data-default || "/playground";