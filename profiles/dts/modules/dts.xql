xquery version "3.1";

module namespace dts="http://teipublisher.com/api/dts";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace dts-config="http://teipublisher.com/api/dts/config" at "dts-config.xql";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace http="http://expath.org/ns/http-client" at "java:org.exist.xquery.modules.httpclient.HTTPClientModule";
import module namespace router="http://e-editiones.org/roaster";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare %private function dts:base-path() {
    let $appLink := substring-after($config:app-root, repo:get-root())
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "api", "dts"), "/")
    return
        replace($path, "/+", "/")
};

(:~ 
 : DTS Entry Endpoint
 : @see https://distributed-text-services.github.io/specifications/entry-point/1.0rc1.html
 : @param request The request map
 : @return the base path for the 3 endpoints: collection, navigation and documents
 :)
declare function dts:entry($request as map(*)) {
    let $base := dts:base-path()
    return
        map {
            "@context": "https://distributed-text-services.github.io/specifications/context/1.0rc1.json",
            "@type": "EntryPoint",
            "@id": "/api/dts",
            "dtsVersion": "1.0.rc",
            "collection": $base || "/collection/{?id,page,nav}",
            "navigation": $base || "/navigation/{?resource,ref,start,end,down,tree,page}",
            "document": $base || "/document/{?resource,ref,start,end,tree,mediaType}"
        }
};

(:~ 
 : DTS Collection Endpoint
 : @see https://distributed-text-services.github.io/specifications/collection/1.0rc1.html
 : @param request The request map
 : @return the collection information for the given id
 :)
declare function dts:collection($request as map(*)) {
    let $collectionInfo :=
        if ($request?parameters?id) then
            dts:collection-by-id($dts-config:collections, $request?parameters?id, (), $request?parameters?nav = "parents")
        else
            $dts-config:collections
    return
        if (exists($collectionInfo)) then
            let $pageSize := xs:int(($request?parameters?per-page, $dts-config:page-size)[1])
            let $resources := dts:get-members($collectionInfo, $request?parameters?page, $pageSize)
            let $parentInfo := 
                if ($request?parameters?id) then
                    dts:collection-by-id($dts-config:collections, $request?parameters?id, (), true())
                else
                    ()
            return map:merge((
                map {
                    "@context": "https://distributed-text-services.github.io/specifications/context/1.0rc1.json",
                    "@type": "Collection",
                    "@id": $collectionInfo?id,
                    "dtsVersion": "1.0.rc",
                    "title": $collectionInfo?title,
                    "totalItems": $resources?total,
                    "totalChildren": $resources?total,
                    "totalParents": count($parentInfo),
                    "dublinCore": $collectionInfo?dublinCore,
                    "collection": dts:base-path() || "/collection?id=" || $collectionInfo?id || "{&amp;page,nav}",
                    "member": array { $resources?items }
                },
                dts:pagination-info($collectionInfo, $request?parameters?page, $resources?total)
            ))
        else
            response:set-status-code(404)
};

declare %private function dts:pagination-info($collectionInfo as map(*), $page as xs:int, $count as xs:int) {
    if ($count > $dts-config:page-size) then
        map {
            "view":
                map:merge((
                    map {
                        "@type": "Pagination",
                        "@id": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || $page,
                        "first": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=1",
                        "last": dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ceiling($count div $dts-config:page-size)
                    },
                    if ($page > 1) then
                        map:entry("previous", dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ($page - 1))
                    else (),
                    if ($page < ceiling($count div $dts-config:page-size)) then
                        map:entry("next", dts:base-path() || "/collection?id=" || $collectionInfo?id || "&amp;page=" || ($page + 1))
                    else ()
                ))
        }
    else ()
};

declare %private function dts:collection-by-id($collectionInfo as map(*), $id as xs:string, $parentInfo as map(*)?, 
    $returnParent as xs:boolean?) {
    if ($collectionInfo?id = $id) then
        if ($returnParent) then $parentInfo else $collectionInfo
    else
        for $member in $collectionInfo?members?*
        return
            dts:collection-by-id($member, $id, $collectionInfo, $returnParent)
};

declare %private function dts:get-members($collectionInfo as map(*), $page as xs:int, $pageSize as xs:int) {
    if (map:contains($collectionInfo, "members")) then
        map {
            "total": count($collectionInfo?members?*),
            "items": 
                for $resource in $collectionInfo?members?*
                return
                    map {
                        "@id": $resource?id,
                        "title": $resource?title,
                        "dublinCore": $resource?dublinCore,
                        "@type": "Collection",
                        "collection": dts:base-path() || "/collection?id=" || $resource?id || "{&amp;page,nav}"
                    }
        }
    else
        let $collectionPath :=
            if (map:contains($collectionInfo, "path")) then $collectionInfo?path else $config:data-default
        let $resources :=
            collection($collectionPath)//tei:text[ft:query(., "file:*", $query:QUERY_OPTIONS)]
        return
            map {
                "total": count($resources),
                "items": 
                    for $resource in subsequence($resources, ($page - 1) * $pageSize + 1, $pageSize)
                    let $id := util:document-name($resource)
                    return
                        map:merge((
                            map {
                                "@id": $collectionInfo?id || "/" || $id,
                                "title": $id,
                                "@type": "Resource",
                                "totalParents": 1,
                                "totalChildren": 0,
                                "collection": dts:base-path() || "/collection?id=" || encode-for-uri($collectionInfo?id) || "{&amp;page,nav}",
                                "document": dts:base-path() || "/document?resource=" || encode-for-uri($collectionInfo?id || "/" || $id) || "{&amp;ref,start,end,tree,mediaType}",
                                "navigation": dts:base-path() || "/navigation?resource=" || encode-for-uri($collectionInfo?id || "/" || $id) || "{&amp;down}"
                            },
                            dts:metadata($resource)
                        ))
            }
};

(:~ 
 : DTS Documents Endpoint
 : @see https://distributed-text-services.github.io/specifications/document/1.0rc1.html
 : @param request The request map
 : @return the document information for the given resource
 :)
declare function dts:document($request as map(*)) {
    let $collection := dts:collection-by-id($dts-config:collections, substring-before($request?parameters?resource, "/"), (), false())
    let $doc := doc($collection?path || "/" || substring-after($request?parameters?resource, "/"))
    return
        if ($doc) then
            let $xml := dts:resolve-fragment($doc, $request?parameters?ref)
            return
                if ($xml instance of document-node()) then (
                    util:declare-option("output:method", "xml"),
                    util:declare-option("output:media-type", "application/tei+xml"),
                    dts:check-pi(root($xml))
                ) else if ($xml instance of element()) then
                    document {
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <dts:wrapper xmlns:dts="https://w3id.org/api/dts#">
                                {$xml}
                            </dts:wrapper>
                        </TEI>
                    }
                else if ($xml instance of attribute()) then
                    $xml
                else
                    response:set-status-code(404)
        else
            response:set-status-code(404)
};

(:~ 
 : DTS Navigation Endpoint
 : @see https://distributed-text-services.github.io/specifications/navigation/1.0rc1.html
 : @param request The request map
 : @return the navigation information for the given resource
 :)
declare function dts:navigation($request as map(*)) {
    let $collection := dts:collection-by-id($dts-config:collections, substring-before($request?parameters?resource, "/"), (), false())
    let $doc := 
        doc($collection?path || "/" || substring-after($request?parameters?resource, "/"))//tei:text[ft:query(., "file:*", $query:QUERY_OPTIONS)]
    let $config := tpu:parse-pi(root($doc), ())
    return
        map {
            "@context": "https://distributed-text-services.github.io/specifications/context/1.0rc1.json",
            "dtsVersion": "1.0rc1",
            "@type": "Navigation",
            "@id": dts:base-path() || "/navigation?resource=" || $request?parameters?resource,
            "resource":
                let $id := util:document-name($doc)
                return
                    map:merge((
                        map {
                            "@id": $collection?id || "/" || $id,
                            "title": $id,
                            "@type": "Resource",
                            "totalParents": 1,
                            "totalChildren": 0,
                            "collection": dts:base-path() || "/collection?id=" || encode-for-uri($collection?id) || "{&amp;page,nav}",
                            "document": dts:base-path() || "/document?resource=" || encode-for-uri($collection?id || "/" || $id) || "{&amp;ref,start,end,tree,mediaType}"
                        },
                        dts:metadata($doc)
                    )),
            (: "citationTrees": [
                map {
                    "@type": "CitationTree",
                    "citeStructure": [
                        dts:cite-structure($doc//tei:body)
                    ]
                }
            ], :)
            "member": dts:navigation-tree($doc//tei:body/tei:div, $config?odd, $request?parameters?down, 0)
        }
};

declare %private function dts:metadata($doc as element()) {
    map {
        "title": ft:field($doc, "title"),
        "dublinCore":
            map {
                "creator": ft:field($doc, "author"),
                "date": ft:field($doc, "date"),
                "language": ft:field($doc, "language")
            }
    }
};

declare %private function dts:check-pi($doc as document-node()) {
    let $pi := $doc/processing-instruction("teipublisher")
    return
        if ($pi) then
            $doc
        else
            let $config := config:default-config(document-uri($doc))
            return
                document {
                    processing-instruction teipublisher {
                        ``[odd="`{$config?odd}`" view="`{$config?view}`" template="`{$config?template}`"]``
                    },
                    $doc/node()
                }
};

declare %private function dts:store-temp($data as node()*, $name as xs:string) {
    let $tempCol :=
        if (xmldb:collection-available($config:data-root || "/dts")) then
            $config:data-root || "/dts"
        else
            xmldb:create-collection($config:data-root, "dts")
    return
        xmldb:store($tempCol, $name, $data, "application/xml")
};

declare %private function dts:store($data as node()*, $name as xs:string) {
    xmldb:store($dts-config:import-collection, $name, $data, "application/xml")
};

declare %private function dts:clear-temp() {
    let $docs := collection($config:data-root || "/dts")
    let $until := current-dateTime() - xs:dayTimeDuration("P1D")
    for $outdated in xmldb:find-last-modified-until($docs, $until)
    return
        xmldb:remove(util:collection-name($outdated), util:document-name($outdated))
};

declare function dts:import($request as map(*)) {
    dts:clear-temp(),
    let $options := <http:request method="GET" href="{$request?parameters?uri}"/>
    let $response := http:send-request($options)
    return
        if ($response[1]/@status = "200") then (
            let $stored :=
                if ($request?parameters?temp) then
                    dts:store-temp(tail($response), util:hash($request?parameters?uri, "md5") || ".xml")
                else
                    dts:store(tail($response), util:hash($request?parameters?uri, "md5") || ".xml")
            return
                router:response(201, "application/json",
                    map {
                        "path": substring-after($stored, $config:data-root || "/")
                    }
                )
        )
        else
            response:set-status-code($response[1]/@status)
};

declare %private function dts:cite-structure($roots as element()*) {
    for $root in $roots
    return
        map {
            "@type": "CiteStructure",
            "citeType": "Division",
            "citeStructure": [
                dts:cite-structure($root/tei:div)
            ]
        }
};

declare %private function dts:navigation-tree($roots as element()*, $odd as xs:string, $down as xs:int, $level as xs:int) {
    for $root in $roots
    return (
        map {
            "@type": "CitableUnit",
            "citeType": "Division",
            "level": count($root/ancestor::tei:div) + 1,
            "dublinCore": map {
                "title": dts:heading(head($root/tei:head), $odd)
            },
            "parent": dts:get-identifier($root/parent::tei:div),
            "identifier": dts:get-identifier($root)
        },
        if ($down < 0 or $level < $down) then
            dts:navigation-tree($root/tei:div, $odd, $down, $level + 1)
        else
            ()
    )
};

declare %private function dts:heading($root as element()?, $odd as xs:string) {
    if (empty($root)) then
        ()
    else
        $pm-config:web-transform($root, map { "root": $root, "mode": "toc" }, $odd)    
};

declare %private function dts:get-identifier($node as node()?) {
    if (empty($node)) then
        ()
    else
        head(($node/@xml:id/string(), "exist:" || util:node-id($node)))
};

declare %private function dts:resolve-fragment($doc as document-node(), $ref as xs:string?) {
    if (empty($ref)) then
        $doc
    else
        let $xml := $doc/id($ref)
        return
            if ($xml) then
                $xml
            else
                util:node-by-id($doc, substring-after($ref, "exist:"))
};