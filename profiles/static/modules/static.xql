xquery version "3.1";

import module namespace static="http://tei-publisher.com/jinks/static" at "xmldb:exist:///db/apps/jinks/modules/static.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "xmldb:exist:///db/apps/jinks/modules/cpy.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace path="http://tei-publisher.com/jinks/path";

let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/config.json")))
let $baseUri := 
    request:get-scheme() || "://" || request:get-server-name() || ":" || 
    request:get-server-port() ||
    request:get-context-path() || "/apps/" ||
    substring-after(path:get-package-target($jsonConfig?id), repo:get-root())
let $context := map:merge((
    $jsonConfig,
    map {
        "source": $config:app-root,
        "base-uri": $baseUri,
        "context-path": request:get-context-path() || "/apps/" || $jsonConfig?static?target,
        "target": repo:get-root() || "/" || $jsonConfig?static?target,
        "languages": json-doc($config:app-root || "/resources/i18n/languages.json")
    }
))
return (
    path:mkcol($context, $context?target),
    let $docs := static:load($context, $baseUri || "/api/documents")
    let $start := cpy:copy-template(map:merge(($context, map:entry("content", $docs))), "static/templates/index.html", "index.html")
    for $doc in $docs?*
    return
        static:paginate(
            $context,
            [
                map {
                    "path": $doc?path,
                    "xpath": "! (.//text[@xml:lang = 'la']/body | .//text/body)[1]"
                },
                map {
                    "id": "translation",
                    "path": $doc?path,
                    "xpath": "//text[@xml:lang='pl']/body"
                },
                map {
                    "id": "breadcrumb",
                    "path": $doc?path,
                    "xpath": "//titleStmt",
                    "view": "single",
                    "user.mode": "breadcrumb"
                }
            ],
            "static/templates/dta.html", 
            function($context as map(*), $n as xs:int) {
                $doc?path || "/" || $n
            }
        ),
    cpy:copy-template($context, "static/templates/about.html", "about.html"),
    cpy:copy-resource($context, "static/controller.xql", "controller.xql"),
    cpy:copy-collection($context, "resources/css", "resources/css"),
    cpy:copy-collection($context, "resources/images", "resources/images"),
    path:mkcol($context, "transform"),
    cpy:copy-resource($context, "transform/serafin.css", "transform/serafin.css"),
    cpy:copy-collection($context, "resources/fonts", "resources/fonts")
    (: path:mkcol($context, "site/iiif"),
    static:load($context, $context?context-path || "/api/iiif/F-rom.xml", "site/iiif/F-rom.xml.json") :)
)