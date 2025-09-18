xquery version "3.1";

module namespace dts-config="http://teipublisher.com/api/dts/config";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "navigation.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $dts-config:collections := map {
    "id": "default",
    "title": $config:expath-descriptor/expath:title/string(),
    "members": [
        [% for $collection in $context?features?dts?collections?* %]
        map {
            "id": "[[ $collection?id ]]",
            "title": "[[ $collection?title ]]",
            "path": $config:data-root || "/[[ $collection?path ]]"
            [% if exists($collection?dublinCore) %]
            ,"dublinCore": [[ serialize($collection?dublinCore, map { "method": "adaptive", "indent": true() }) ]]
            [% endif %]
        },
        [% endfor %]
        map {
            "id": "odd",
            "title": "ODD Collection",
            "path": $config:odd-root
        }
    ]
};

declare variable $dts-config:page-size := 10;

declare variable $dts-config:import-collection := $config:data-default || "/playground";