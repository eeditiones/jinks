xquery version "3.1";

module namespace page="http://teipublisher.com/ns/templates/page";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "../pm-config.xql";
import module namespace mapping="http://www.tei-c.org/tei-simple/components/map" at "../map.xql";
import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "../lib/pages.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "../lib/util.xql";

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
        let $xml := tpu:fragment($context, $context?doc?content, $view, $context?doc?path, $xpath)
        return
            if (exists($xml?data)) then
                let $content :=
                    if ($view = "single") then
                        $xml?data
                    else
                        pages:get-content($xml?config, $xml?data)
                let $nodeId := util:node-id($xml?data[1])
                let $rendered := page:unwrap-body(
                    pages:process-content($content, $xml?data, $xml?config, map { "webcomponents": 7 }, ())
                )
                (: process-content collects footnotes into a sibling <div class="footnotes">
                 : (wrapping everything in a content div). Split it out so the markup
                 : matches the parts API response (resp.content / resp.footnotes) and
                 : pb-view can adopt content and footnotes the same way for SSR and
                 : dynamic loads. :)
                let $footnotes := $rendered/div[@class = "footnotes"]
                return
                    (
                        (: Content block; pb-view detects this marker, adopts it into
                         : its shadow DOM and requests content=none so the fragment is
                         : not rendered a second time. :)
                        element div {
                            attribute data-pb-ssr { $nodeId },
                            if (exists($footnotes)) then
                                element { node-name($rendered) } {
                                    $rendered/@*,
                                    $rendered/node() except $footnotes
                                }
                            else
                                $rendered
                        },
                        if (exists($footnotes)) then
                            element div {
                                attribute data-pb-ssr-footnotes { $nodeId },
                                $footnotes
                            }
                        else
                            ()
                    )
            else
                ()
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