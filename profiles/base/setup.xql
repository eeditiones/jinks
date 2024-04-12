xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy";

declare %generator:custom variable $teip:ERROR_TEIP_NOT_INSTALLED := xs:QName("teip:not-installed");

declare 
    %generator:prepare
function teip:prepare($context as map(*)) {
    let $teipPath := generator:get-package-target("http://existsolutions.com/apps/tei-publisher")
    return
        if (empty($teipPath)) then
            error($teip:ERROR_TEIP_NOT_INSTALLED, "tei-publisher-app is not installed")
            (: repo:install("http://existsolutions.com/apps/tei-publisher") :)
        else
            map {
                "publisher": $teipPath
            }
};

declare 
    %generator:write
function teip:setup($context as map(*)) {
    cpy:copy-collection($context),
    cpy:copy-collection($context, $context?publisher || "/modules/lib", "modules/lib"),
    cpy:copy-collection($context, $context?publisher || "/data/registers", "data/registers"),
    cpy:mkcol($context, "resources/scripts"),
    cpy:copy-resource($context, $context?publisher || "/resources/scripts/browse.js", "resources/scripts/browse.js"),
    cpy:copy-resource($context, $context?publisher || "/data/taxonomy.xml", "data/taxonomy.xml"),
    cpy:copy-resource($context, $context?publisher || "/templates/api.html", "templates/api.html"),
    for $lib in (
        "map.xql", "facets.xql", "registers.xql", 
        "annotation-config.xqm", "nlp-config.xqm", 
        "iiif-config.xqm", 
        xmldb:get-child-resources($context?publisher || "/modules")[starts-with(., "navigation")],
        xmldb:get-child-resources($context?publisher || "/modules")[starts-with(., "query")]
    )
    return
        cpy:copy-resource($context, $context?publisher || "/modules/" || $lib, "modules/" || $lib),
    teip:install-odd($context),
    teip:install-pages($context)
};

declare %private function teip:install-pages($context as map(*)) {
    cpy:mkcol($context, "templates/pages"),
    for $page in $context?pages?*
    return
        cpy:copy-resource($context, $context?publisher || "/templates/pages/" || $page, 
            "templates/pages/" || $page)
};

declare %private function teip:install-odd($context as map(*)) {
    for $file in distinct-values($context?odds?*)
    let $source := doc($context?publisher || "/odd/" || $file)
    let $cssLink := $source//tei:teiHeader/tei:encodingDesc/tei:tagsDecl/tei:rendition/@source
    let $css := util:binary-doc-available($context?publisher || "/odd/" || $cssLink)
    return (
        cpy:copy-resource($context, $context?publisher || "/odd/" || $file, "resources/odd/" || $file),
        if ($css) then
            cpy:copy-resource($context, $context?publisher || "/odd/" || $cssLink,
                $context?target || "/resources/odd/" || $cssLink)
        else
            ()
    )[3]
};