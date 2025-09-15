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
        map {
            "id": "demo",
            "title": "Demo Collection",
            "path": $config:data-root || "/demo"
        },
        map {
            "id": "serafin",
            "title": "Korespondencja żupnika krakowskiego Mikołaja Serafina z lat 1437-1459",
            "path": $config:data-root || "/letters",
            "dublinCore": map {
                "title": [
                    map {
                        "lang": "pl",
                        "value": "Korespondencja żupnika krakowskiego Mikołaja Serafina z lat 1437-1459"
                    }
                ],
                "creator": [
                    "Anna Skolimowska",
                    "Waldemar Bukowski",
                    "Tomasz Płóciennik"
                ]
            }
        },
        map {
            "id": "odd",
            "title": "ODD Collection",
            "path": $config:odd-root,
            "metadata": function($doc as document-node()) {
                map {
                    "title": string-join($doc//tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[not(@type)], "; ")
                }
            }
        }
    ]
};

declare variable $dts-config:page-size := 10;

declare variable $dts-config:import-collection := $config:data-default || "/playground";