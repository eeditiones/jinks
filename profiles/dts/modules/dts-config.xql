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
    "memberCollections": (
            map {
                "id": "documents",
                "title": "Document Collection",
                "path": $config:data-default,
                "members": function() {
                    nav:get-root((), map {
                        "leading-wildcard": "yes",
                        "filter-rewrite": "yes"
                    })
                },
                "metadata": function($doc as document-node()) {
                    let $properties := tpu:parse-pi($doc, ())
                    return
                        map:merge((
                            map:entry("title", nav:get-metadata($properties, $doc/*, "title")/string()),
                            map {
                                "dts:dublincore": map {
                                    "dc:creator": string-join(nav:get-metadata($properties, $doc/*, "author"), "; "),
                                    "dc:license": nav:get-metadata($properties, $doc/*, "license")
                                }
                            }
                        ))
                }
            },
            map {
                "id": "odd",
                "title": "ODD Collection",
                "path": $config:odd-root,
                "members": function() {
                    collection($config:odd-root)/tei:TEI
                },
                "metadata": function($doc as document-node()) {
                    map {
                        "title": string-join($doc//tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[not(@type)], "; ")
                    }
                }
            }
    )
};

declare variable $dts-config:page-size := 10;

declare variable $dts-config:import-collection := $config:data-default || "/playground";