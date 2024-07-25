xquery version "3.1";

module namespace browse="http://teipublisher.com/ns/templates/browse";

import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../util.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../navigation.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "../query.xql";
import module namespace kwic="http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";

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

declare function browse:show-hits($context as map(*), $doc as element()) {
    if (exists($context?request?parameters?query) and $context?request?parameters?query != '') then
        let $fieldName := head(($context?request?parameters?field, "text"))
        for $field in ft:highlight-field-matches($doc, query:field-prefix($doc) || $fieldName)
        let $matches := $field//exist:match
        return
            <div class="matches">
                <div class="count"><pb-i18n key="browse.items" options='{{"count": {count($matches)}}}'></pb-i18n></div>
                {
                    for $match in subsequence($matches, 1, 5)
                    let $config := <config width="60" table="no"/>
                    return
                        kwic:get-summary($field, $match, $config)
                }
            </div>
    else
        ()
};