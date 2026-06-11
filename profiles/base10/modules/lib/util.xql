(:
 :
 :  Copyright (C) 2017 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.1";

module namespace tpu="http://www.tei-c.org/tei-publisher/util";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "../navigation.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "pages.xql";

declare function tpu:parse-pi($doc as document-node(), $view as xs:string?) {
    tpu:parse-pi($doc, $view, request:get-parameter("odd", ()))
};

declare function tpu:parse-pi($doc as document-node(), $view as xs:string?, $odd as xs:string?) {
    let $fill := request:get-parameter("fill", ())
    return
        tpu:parse-pi($doc, $view, $odd, if ($fill) then number($fill) else ())
};

declare function tpu:parse-pi($doc as document-node(), $view as xs:string?, $odd as xs:string?, $fill as xs:double?) {
    let $defaultConfig := config:default-config(document-uri($doc))
    let $newConfig := map {
        "view": ($view, $defaultConfig?view)[1],
        "type": config:document-type($doc/*),
        "fill": ($fill, $defaultConfig?fill)[1]
    }
    let $default := map:merge((
        $defaultConfig, $newConfig
    ), map { "duplicates": "use-last" })
    let $pis :=
        map:merge(
            for $pi in $doc/processing-instruction("teipublisher")
            let $analyzed := analyze-string($pi, '([^\s]+)\s*=\s*"(.*?)"')
            for $match in $analyzed/fn:match
            let $key := $match/fn:group[@nr="1"]/string()
            let $value := $match/fn:group[@nr="2"]/string()
            return
                if ($key = "view" and $value != $view) then
                    ()
                else if ($key = ('depth', 'fill')) then
                    map:entry($key, number($value))
                else if ($key = 'media') then
                    map:entry($key, tokenize($value, '[\s,]+'))
                else
                    map:entry($key, $value)
        , map { "duplicates": "use-last" })
    (: Check if ODD configured in PI is available :)
    let $cfgOddAvail :=
        if ($pis?odd) then
            doc-available($config:odd-root || "/" || $pis?odd)
        else
            false()
    let $pisWithOdd :=
        if ($defaultConfig?overwrite) then
            if ($cfgOddAvail) then
                map:merge(($default, map { "odd": $pis?odd, "output": $pis?output }), map { "duplicates": "use-last" })
            else
                map:merge(($default, map { "output": $pis?output }), map { "duplicates": "use-last" })
        else
            $pis
    (: ODD from parameter should overwrite ODD defined in PI :)
    let $config :=
        if ($odd) then
            map:merge(($pisWithOdd, map { "odd": $odd }), map { "duplicates": "use-last" })
        else if ($cfgOddAvail) then
            $pisWithOdd
        else
            map:merge(($pisWithOdd, map { "odd": $defaultConfig?odd }), map { "duplicates": "use-last" })
    return
        map:merge(($default, $config), map { "duplicates": "use-last" })
};

declare function tpu:parameter($context as map(*), $name as xs:string) {
    tpu:parameter($context, $name, ())
};

(:~
 : Get a parameter from the request. Return the default value if the parameter
 : is not present.
 :)
declare function tpu:parameter($context as map(*), $name as xs:string, $default as item()*) {
    let $reqParam := head(($context?request?parameters?($name), request:get-parameter($name, ())))
    return
        if (exists($reqParam)) then
            $reqParam
        else
            $default
};

(:~ Narrow $data to the nodes selected by $xpath, evaluated with the document's
 : default element namespace. Mirrors dapi:apply-xpath in the document API. :)
declare %private function tpu:apply-xpath($data as node()*, $xpath as xs:string?) {
    if ($xpath) then
        let $namespace := namespace-uri-from-QName(node-name(root($data[1])/*))
        return
            util:eval("declare default element namespace '" || $namespace || "'; $data" || $xpath)
    else
        $data
};

(:~
 : Resolve the fragment requested by the current page URL to a { config, data }
 : map, mirroring the selection of the parts API (dapi:get-fragment) so a page
 : URL and its corresponding parts/{doc}/json request return the same fragment.
 :
 : $xpath, when given, scopes the lookup to a sub-document (e.g. a
 : source/translation column) before the fragment is resolved within it. The
 : persistent "id" (xml:id) parameter wins over the volatile "root" (node id);
 : it is resolved to an actual node (for "div" view expanded to its section via
 : nav:get-section-for-node), never round-tripped through util:node-id. With no
 : resolvable id, pages:load-xml handles the "root" node id or the first fragment.
 :
 : @param $context templating context, used only to read the id/root parameters
 : @param $document the full document content
 : @param $view the view (div/page/single/...)
 : @param $path the document path, passed through to pages:load-xml
 : @param $xpath optional expression scoping the lookup, or empty for the whole document
 : @return a map with "config" and "data" entries, or empty if nothing resolves
 :)
declare function tpu:fragment($context as map(*), $document as node()*, $view as xs:string?,
    $path as xs:string?, $xpath as xs:string?) as map(*)? {
    let $view := head(($view, $config:default-view))
    let $id := tpu:parameter($context, 'id')
    let $root := tpu:parameter($context, 'root')
    let $ctx := tpu:apply-xpath($document, $xpath)
    let $node :=
        if (string-length(normalize-space($id)) gt 0 and $view != "single") then
            $ctx/id($id)
        else
            ()
    return
        if (exists($node)) then
            let $config := tpu:parse-pi(root($document), $view)
            return
                map {
                    "config": map:merge(($config, map { "context": $ctx }), map { "duplicates": "use-last" }),
                    "data":
                        if ($view = "div") then
                            nav:get-section-for-node($config, $node)
                        else
                            $node
                }
        else if (exists($ctx)) then
            pages:load-xml($ctx, $view, $root, $path)
        else
            ()
};