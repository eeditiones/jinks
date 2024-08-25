xquery version "3.1";

module namespace teip="https://teipublisher.com/generator/setup";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace expath="http://expath.org/ns/pkg";

import module namespace generator="http://tei-publisher.com/library/generator" at "../../modules/generator.xql";
import module namespace cpy="http://tei-publisher.com/library/generator/copy" at "../../modules/cpy.xql";
import module namespace path="http://tei-publisher.com/jinks/path" at "../../modules/paths.xql";

declare variable $teip:ERROR_TEIP_NOT_INSTALLED := xs:QName("teip:not-installed");

declare variable $teip:TEIP_PKG_ID := "http://existsolutions.com/apps/tei-publisher";

declare 
    %generator:prepare
function teip:prepare($context as map(*)) {
    let $teipPath := path:get-package-target($teip:TEIP_PKG_ID)
    let $teipVersion := 
        generator:get-package-descriptor($teip:TEIP_PKG_ID)/expath:package/@version
    return
        if (empty($teipPath)) then
            error($teip:ERROR_TEIP_NOT_INSTALLED, "tei-publisher-app is not installed")
            (: repo:install("http://existsolutions.com/apps/tei-publisher") :)
        else
            map {
                "publisher": $teipPath,
                "publisherVersion": $teipVersion
            }
};

declare 
    %generator:write
function teip:setup($context as map(*)) {
    util:log("INFO", "base10: Start copying files ..."),
    cpy:copy-collection($context, $context?publisher || "/modules/lib", "modules/lib"),
    teip:install-odd($context),
    cpy:copy-collection($context),
    cpy:copy-collection($context, $context?publisher || "/data/registers", "data/registers"),
    path:mkcol($context, "resources/scripts"),
    cpy:copy-resource($context, $context?publisher || "/resources/scripts/browse.js", "resources/scripts/browse.js"),
    cpy:copy-resource($context, $context?publisher || "/data/taxonomy.xml", "data/taxonomy.xml"),
    cpy:copy-resource($context, $context?publisher || "/templates/api.html", "templates/api.html"),
    for $lib in (
        "map.xql", "facets.xql", "registers.xql", 
        "annotation-config.xqm", "nlp-config.xqm", 
        "iiif-config.xqm"
    )
    return
        cpy:copy-resource($context, $context?publisher || "/modules/" || $lib, "modules/" || $lib),
    teip:install-pages($context),
    util:log("INFO", "base10: copying files done.")
};

declare %private function teip:install-pages($context as map(*)) {
    if ($context?pages instance of array(*)) then (
        path:mkcol($context, "templates/pages"),
        for $page in $context?pages?*
        return
            cpy:copy-resource($context, $context?publisher || "/templates/pages/" || $page, 
                "templates/pages/" || $page)
    ) else
        ()
};

declare %private function teip:install-odd($context as map(*)) {
    path:mkcol($context, "resources/odd"),
    for $file in $context?odds?*
    let $source := doc($context?publisher || "/odd/" || $file)
    return
        if (exists($source)) then
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
        else
            ()
};