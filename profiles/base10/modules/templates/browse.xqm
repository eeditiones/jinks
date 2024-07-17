xquery version "3.1";

module namespace browse="http://teipublisher.com/ns/templates/browse";

import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../util.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../navigation.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function browse:document-options($doc as element()) {
    let $config := tpu:parse-pi(root($doc), ())
    return map:merge((
        $config,
        map {
            "relpath": config:get-relpath($doc),
            "odd": head(($config?odd, $config:default-odd))
        }
    ))
};

declare function browse:header($context as map(*), $doc as element(), $config as map(*)) {
    let $relPath := config:get-identifier($doc)
    return
        try {
            let $config := tpu:parse-pi(root($doc), (), ())
            let $teiHeader := nav:get-header($config, root($doc)/*)
            let $header :=
                $pm-config:web-transform($teiHeader, map {
                    "header": "short",
                    "doc": $relPath
                }, $config?odd)
            return
                if ($header) then
                    $header
                else
                    <a href="{$relPath}">{$header}</a>
        } catch * {
            <a href="{$relPath}">{util:document-name($doc)}</a>,
            <p class="error">Failed to output document metadata: {$err:description}</p>
        }
};