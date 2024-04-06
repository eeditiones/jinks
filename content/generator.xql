xquery version "3.1";

module namespace generator="http://tei-publisher.com/library/generator";

import module namespace cpy="http://tei-publisher.com/library/generator/copy";
import module namespace inspect="http://exist-db.org/xquery/inspection";

declare variable $generator:NAMESPACE := "http://tei-publisher.com/library/generator";

declare variable $generator:ERROR_NOT_FOUND := xs:QName("generator:not-found");

declare function generator:write($collection as xs:string) {
    if (util:binary-doc-available($collection || "/setup.xql")) then
        let $funcs := inspect:module-functions(xs:anyURI($collection || "/setup.xql"))
        let $writeFunc := generator:find-callback($funcs, "write")
        let $config := generator:config($collection, $writeFunc?1/value[1])
        return (
            if (exists($writeFunc)) then
                ($writeFunc?2)($config)
            else
                error($generator:ERROR_NOT_FOUND, "No 'write' function found in " || $collection),
            cpy:deploy($config?config?target)
        )
    else
        let $config := generator:config($collection, ())
        return (
            cpy:copy-collection($config, "", ""),
            cpy:deploy($config?config?target)
        )
};

declare %private function generator:find-callback($funcs as function(*)*, $type as xs:string) {
    fold-right($funcs, (), function($func, $in) {
        if ($in) then
            $in
        else
            let $desc := inspect:inspect-function($func)
            let $anno := 
                $desc/annotation[@namespace = $generator:NAMESPACE]
                    [replace($desc/annotation/@name, "^.*?:(.*)$", "$1") = $type]
            return
                if ($anno) then
                    [$anno, $func]
                else
                    ()
    })
};

declare %private function generator:config($collection as xs:string, $target as xs:string?) {
    let $userConfig :=
        if (util:binary-doc-available($collection || "/config.json")) then
            util:binary-doc($collection || "/config.json")
            => util:binary-to-string()
            => parse-json()
        else
            map {}
    return
        map:merge((
            $userConfig,
            map {
                "config": map {
                    "source": $collection,
                    "target": head(($target, "/db/system/temp/" || tokenize($collection, "/")[last()])),
                    "template-suffix": ".tpl"
                }
            })
        )
};