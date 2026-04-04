xquery version "3.1";

(:~
 : Query module for markdown documents.
 : Finds pre-parsed .md.xml files via Lucene full-text index.
 :)
module namespace mds="http://exist-db.org/apps/sandbox/query-md";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";

declare namespace mdns="http://exist-db.org/xquery/markdown";

declare variable $mds:FIELD_PREFIX := "md.";

declare function mds:query-metadata(
    $path as xs:string?,
    $field as xs:string?,
    $query as xs:string?,
    $sort as xs:string
) {
    let $queryExpr :=
        if ($field = "file" or empty($query) or $query = '') then
            "file:*"
        else
            $mds:FIELD_PREFIX || ($field, "text")[1] || ":" || $query
    let $options := map {
        "leading-wildcard": "yes",
        "filter-rewrite": "yes",
        "fields": ($mds:FIELD_PREFIX || "title", $mds:FIELD_PREFIX || "file")
    }
    let $result :=
        $config:data-default ! (
            collection(. || "/" || $path)//mdns:document[ft:query(., $queryExpr, $options)]
        )
    return
        for $doc in $result
        let $title := ft:field($doc, "md.title", "xs:string")[1]
        order by
            if ($sort = "title") then lower-case($title)
            else lower-case($title)
        return $doc
};
