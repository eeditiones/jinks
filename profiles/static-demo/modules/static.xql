xquery version "3.1";

import module namespace static="http://tei-publisher.com/jinks/static" at "xmldb:exist:///db/apps/jinks/modules/static.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "xmldb:exist:///db/apps/jinks/modules/cpy.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace path="http://tei-publisher.com/jinks/path";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

declare function local:letters($context as map(*), $baseUri as xs:string) {
    (: Load documents and their titles via the API :)
    let $letters := static:load($baseUri || "/api/documents/letters?link=" || $context?context-path || "/documents")
    return (
        (: Create search index :)
        static:index($context, $letters?*, 'single'),
        (: Create the browse page by splitting the documents into chunks of 10 :)
        static:split($context, $letters?*, 10, "static/templates/index.html", function($context as map(*), $page as xs:int) {
            "letters/" || $page
        }),
        (: Create document view for each document :)
        for $doc in $letters?*
        return
            static:paginate(
                $context,
                [
                    map {
                        "path": $doc?path,
                        "xpath": "! (.//text[@xml:lang = 'la']/body | .//text/body)[1]",
                        "odd": "serafin.odd"
                    },
                    map {
                        "id": "translation",
                        "path": $doc?path,
                        "odd": "serafin.odd",
                        "xpath": "//text[@xml:lang='pl']/body"
                    },
                    map {
                        "id": "breadcrumb",
                        "path": $doc?path,
                        "odd": "serafin.odd",
                        "xpath": "//titleStmt",
                        "view": "single",
                        "user.mode": "breadcrumb"
                    },
                    map {
                        "id": "register",
                        "odd": "serafin.odd",
                        "path": $doc?path,
                        "user.mode": "register"
                    }
                ],
                "static/templates/registers.html", 
                function($context as map(*), $n as xs:int) {
                    "documents/" || $doc?path || "/" || $n
                }
            )
    )
};

declare function local:monographs($context as map(*), $baseUri as xs:string) {
    let $monographs := static:load($baseUri || "/api/documents/monograph?link=" || $context?context-path || "/documents")
    return (
        (: Create search index :)
        static:index($context, $monographs?*, 'div'),

        static:split($context, $monographs?*, 10, "static/templates/index.html", function($context as map(*), $page as xs:int) {
            "monograph/" || $page
        }),
        for $doc in $monographs?*
        return
            static:paginate(
                $context,
                [
                    map {
                        "path": $doc?path,
                        "odd": "dta.odd",
                        "view": "div"
                    },
                    map {
                        "id": "breadcrumb",
                        "path": $doc?path,
                        "odd": "dta.odd",
                        "xpath": "//teiHeader/fileDesc/titleStmt/title[@type='main']",
                        "view": "single",
                        "user.mode": "breadcrumb"
                    }
                ],
                "static/templates/monograph.html",
                function($context as map(*), $n as xs:int) {
                    "documents/" || $doc?path || "/" || $n
                }
            ),
            ()
    )
};

let $jsonConfig := parse-json(util:binary-to-string(util:binary-doc($config:app-root || "/context.json")))
let $baseUri := 
    request:get-scheme() || "://" || request:get-server-name() || ":" || 
    request:get-server-port() ||
    request:get-context-path() || "/apps/" ||
    substring-after(path:get-package-target($jsonConfig?id), repo:get-root())
let $context := map:merge((
    $jsonConfig,
    map {
        "isStatic": true(),
        "source": $config:app-root,
        "base-uri": $baseUri,
        "force-overwrite": true(),
        "context-path": request:get-context-path() || "/apps/" || $jsonConfig?static?target,
        "target": repo:get-root() || "/" || $jsonConfig?static?target,
        "languages": json-doc($config:app-root || "/resources/i18n/languages.json")
    }
))
return (
    if (xmldb:collection-available($context?target)) then path:rmcol($context, $context?target) else (),
    path:mkcol($context, $context?target),
    local:monographs($context, $baseUri),
    local:letters($context, $baseUri),
    cpy:copy-template($context, "static/templates/start.html", "index.html"),
    cpy:copy-template($context, "static/templates/about.html", "about.html"),
    cpy:copy-template($context, "static/templates/search.html", "search.html"),
    cpy:copy-resource($context, "static/controller.xql", "controller.xql"),
    cpy:copy-collection($context, "resources/scripts", "resources/scripts"),
    cpy:copy-resource($context, "static/search.js", "resources/scripts/search.js"),
    cpy:copy-collection($context, "resources/css", "resources/css"),
    cpy:copy-resource($context, "static/templates/static.css", "resources/css/static.css"),
    cpy:copy-collection($context, "resources/images", "resources/images"),
    cpy:copy-collection($context, "resources/fonts", "resources/fonts"),
    cpy:copy-collection($context, "resources/i18n", "resources/i18n"),
    path:mkcol($context, "transform"),
    cpy:copy-resource($context, "transform/serafin.css", "transform/serafin.css"),
    cpy:copy-resource($context, "transform/dta.css", "transform/dta.css"),
    static:fix-links($context),
    ()
)