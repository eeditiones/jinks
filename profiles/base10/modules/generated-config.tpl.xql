xquery version "3.1";

(:~
 : Generated configuration – do not edit
 :)
module namespace config="https://e-editiones.org/tei-publisher/generator/config";

declare variable $config:webcomponents := "[[$script?webcomponents]]";
declare variable $config:webcomponents-cdn := "[[$script?cdn]]";
declare variable $config:fore := "[[$script?fore]]";

declare variable $config:default-view := "[[$defaults?view]]";
declare variable $config:default-template := "[[$defaults?template]]";
declare variable $config:default-media := ([[string-join($defaults?media?* ! ('"' || . || '"'), ", ")]]);
declare variable $config:search-default := "[[$defaults?search]]";

[% if map:contains($defaults, "data") %]
    [% if starts-with($defaults?data, "/") %]
    declare variable $config:data-root := "[[$defaults?data]]";
    [% else %]
    declare variable $config:data-root := $config:app-root || "/[[$defaults?data]]";
    [% endif %]
[% else %]
    declare variable $config:data-root := $config:app-root || "/data";
[% endif %]

[% if $defaults?data-default %]
    [% if starts-with($defaults?data-default, "/") %]
    declare variable $config:data-default := "[[$defaults?data-default]]";
    [% else %]
    declare variable $config:data-default := $config:data-root || "/[[$defaults?data-default]]";
    [% endif %]
[% else %]
    declare variable $config:data-default := $config:data-root;
[% endif %]

declare variable $config:default-odd := "[[$defaults?odd]]";
declare variable $config:odd-available := ( [[string-join($odds?*[. != "docx.odd"] ! ('"' || . || '"'), ", ")]] );

(:
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:pagination-depth := [[ $defaults?pagination?depth ]];

declare variable $config:pagination-fill := [[ $defaults?pagination?fill ]];

declare variable $config:address-by-id as xs:boolean := [%if $defaults?address-by-id %] true() [% else %] false() [% endif %];

declare variable $config:default-language as xs:string := "[[ $context?defaults?language ]]";

(:~
 : Use the JSON configuration to determine which configuration applies for which collection
 :)
declare function config:collection-config($collection as xs:string?, $docUri as xs:string?) {
    [% if exists($context?collection-config) %]
    let $prefix := replace($collection, "^([^/]+).*$", "$1") return
    switch ($prefix)
        [% for $relativeCollectionPath in map:keys($context?collection-config) %]
        case "[[$relativeCollectionPath]]" return
            [[ serialize($context?collection-config($relativeCollectionPath), map { "method": "adaptive" }) ]]
        [% endfor %]
        default return
            ()
    [% else %]
    (: No special overrides apply. Return the default in all cases:)
        ()
    [% endif %]
};
