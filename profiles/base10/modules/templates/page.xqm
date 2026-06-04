xquery version "3.1";

module namespace page="http://teipublisher.com/ns/templates/page";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace mapping="http://www.tei-c.org/tei-simple/components/map" at "../map.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "../lib/pages.xql";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $page:EXIDE :=
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");

declare function page:system() {
    map {
        "publisher": $config:expath-descriptor/@version/string(),
        "api": json-doc($config:app-root || "/modules/lib/api.json")?info?version
    }
};

declare function page:parameter($context as map(*), $name as xs:string) {
    page:parameter($context, $name, ())
};

(:~
 : Get a parameter from the request. Return the default value if the parameter
 : is not present.
 :)
declare function page:parameter($context as map(*), $name as xs:string, $default as item()*) {
    let $reqParam := head(($context?request?parameters?($name), request:get-parameter($name, ())))
    return
        if (exists($reqParam)) then
            $reqParam
        else
            $default
};

(:~ Primary language subtag, lowercase (e.g. en-US → en). :)
declare %private function page:primary-lang($tag as xs:string?) as xs:string? {
    if (not(normalize-space($tag))) then
        ()
    else
        let $range := tokenize(normalize-space($tag), ';')[1]
        let $before-hyphen := head(tokenize($range, '-'))
        return
            lower-case(head(tokenize($before-hyphen, '_')))
};

(:~ First Accept-Language preference that matches a supported code (order preserved). :)
declare %private function page:lang-from-accept-language($header as xs:string?, $supported as xs:string*) as xs:string? {
    if (empty($supported) or not(normalize-space($header))) then
        ()
    else
        head(
            filter(
                tokenize($header, ',') ! page:primary-lang(tokenize(., ';')[1]),
                function ($primary) { $primary and $primary = $supported }
            )
        )
};

(:~
 : Effective UI language: non-empty lang query param (primary subtag), else
 : Accept-Language if it matches defaults/languages, else defaults.language or first default.
 :)
declare function page:resolve-language($context as map(*)) as xs:string? {
    let $param := page:parameter($context, 'lang')
    let $supported := $context?defaults?languages?*
    let $fromHeader := page:lang-from-accept-language(request:get-header('Accept-Language'), $supported)
    return
        if (string-length(normalize-space($param)) gt 0) then
            page:primary-lang($param)
        else
            head(($fromHeader, $context?defaults?language, $context?defaults?languages?1))
};

(:~
 : Generate a breadcrumb trail for the current collection.
 :)
declare function page:collection-breadcrumbs($context as map(*)) {
    if (exists($context?doc)) then
        let $components := config:get-relpath($context?doc?content, $config:data-default) => tokenize("/")
        return
            if (count($components) = 1) then
                <li>
                    <a href="{$context?context-path}/{$context?defaults?browse}?collection=">
                        <pb-i18n key="breadcrumb.document-root">
                            Home
                        </pb-i18n>
                    </a>
                </li>
            else
                for $i in 1 to count($components) - 1
                return
                    <li>
                        <a href="{$context?context-path}/{$context?defaults?browse}?collection={string-join(subsequence($components, 1, $i), '/')}">
                            <pb-i18n key="breadcrumb.{string-join(subsequence($components, 1, $i), '.')}">
                                {$components[$i]}
                            </pb-i18n>
                        </a>
                    </li>
    else ()
};

(:~
 : Render the content fragment requested by the current page URL to HTML, so it
 : can be injected into <pb-view> as light-DOM content. A crawler that does not
 : execute JavaScript (or before the components upgrade) then sees the real text
 : instead of an empty component; <pb-view> ignores this light DOM (it has no
 : <slot>) and still fetches and renders into its shadow DOM for interactive use,
 : so the user experience is unchanged.
 :
 : The fragment is selected from the request parameters the same way as the
 : api/parts/{doc}/json endpoint (dapi:get-fragment): the persistent "id"
 : (xml:id) wins over the volatile "root" (node id); with neither, the first
 : fragment is rendered. This makes every per-fragment URL the sitemap emits
 : (e.g. ?id=intro-jinks) resolve server-side to that fragment's text.
 :
 : @param $context the templating context (expects $context?doc with content/path/view)
 : @return the transformed HTML nodes for the requested fragment, or empty if no document
 :)
declare function page:content($context as map(*)) {
    page:content($context, ())
};

(:~
 : As page:content#1 but first narrows the document to the nodes selected by
 : $xpath, matching a pb-view that carries an xpath attribute (e.g. a
 : source/translation column). Pass the same expression as the pb-view.
 :)
declare function page:content($context as map(*), $xpath as xs:string?) {
    if (exists($context?doc?content)) then
        let $view := head(($context?doc?view, $config:default-view))
        let $data := page:apply-xpath($context?doc?content, $xpath)
        let $root := page:fragment-root($context, $data)
        return
            if (exists($data)) then
                let $xml := pages:load-xml($data, $view, $root, $context?doc?path)
                return
                    if (exists($xml?data)) then
                        let $content :=
                            if ($view = "single") then
                                $xml?data
                            else
                                pages:get-content($xml?config, $xml?data)
                        return
                            page:unwrap-body(
                                pages:process-content($content, $xml?data, $xml?config, map { "webcomponents": 7 }, ())
                            )
                    else
                        ()
            else
                ()
    else
        ()
};

(:~ Resolve the requested fragment to a node id that pages:load-xml understands.
 : Prefers the persistent "id" (xml:id) parameter, resolving it to its node id
 : exactly as the document API does; falls back to a literal "root" node id;
 : returns the empty sequence (first fragment) when neither is present or the id
 : cannot be found. :)
declare %private function page:fragment-root($context as map(*), $data as node()*) as xs:string? {
    let $id := page:parameter($context, 'id')
    let $root := page:parameter($context, 'root')
    return
        if (exists($data) and string-length(normalize-space($id)) gt 0) then
            let $node := head($data)/id($id)
            return
                if (exists($node)) then util:node-id(head($node)) else ()
        else if (string-length(normalize-space($root)) gt 0) then
            $root
        else
            ()
};

(:~ The transform wraps its output in an HTML <body> element. Inlining that into
 : the page would nest a second <body>, which the HTML parser rejects (it closes
 : the real document body early and reparents the content out of <main>). Rewrite
 : any such <body> wrapper to a <div>, keeping attributes and children. Other
 : elements are passed through untouched to preserve their namespaces. :)
declare %private function page:unwrap-body($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch ($node)
            case element(body) return
                element div { $node/@*, $node/node() }
            case element() return
                if ($node/body) then
                    element { node-name($node) } { $node/@*, page:unwrap-body($node/node()) }
                else
                    $node
            default return
                $node
};

(:~ Narrow $data to the nodes selected by $xpath, evaluated with the document's
 : default element namespace. Mirrors dapi:apply-xpath in the document API. :)
declare %private function page:apply-xpath($data as node()*, $xpath as xs:string?) {
    if ($xpath) then
        let $namespace := namespace-uri-from-QName(node-name(root($data[1])/*))
        return
            util:eval("declare default element namespace '" || $namespace || "'; $data" || $xpath)
    else
        $data
};

declare function page:transform($nodes as node()*) {
    page:transform($nodes, (), ())
};

declare function page:transform($nodes as node()*, $parameters as map(*)?) {
    page:transform($nodes, $parameters, ())
};

declare function page:transform($nodes as node()*, $parameters as map(*)?, $odd as xs:string?) {
    page:transform($nodes, $parameters, $odd, ())
};

(:~
 : Transform a sequence of nodes to HTML using the given odd and parameters.
 :
 : @param $nodes the nodes to transform
 : @param $parameters the parameters to use for the transformation
 : @param $odd the odd to use for the transformation
 : @param $mapFunction name of mapping function to apply to the nodes before transformation
 : @return the transformed nodes
 :)
declare function page:transform($nodes as node()*, $parameters as map(*)?, $odd as xs:string?, $mapFunction as xs:string?) {
    let $mappingFun := 
        if ($mapFunction) then
            function-lookup(xs:QName("mapping:" || $mapFunction), 2)
        else
            ()
    let $odd := head(($odd, $config:default-odd))
    for $node in $nodes
    let $mapped :=
        if (exists($mappingFun)) then
            $mappingFun($node, $parameters)
        else
            $node
    let $params := map:merge((
        $parameters,
        map { 
            "webcomponents": 7, 
            "context-path": $config:context-path, 
            "root": head(($parameters?root, $node))
        }
    ))
    return
        $pm-config:web-transform($mapped, $params, $odd)
};