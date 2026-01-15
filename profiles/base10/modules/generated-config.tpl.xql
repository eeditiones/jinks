xquery version "3.1";

(:~
 : Generated configuration – do not edit
 :)
module namespace config="https://e-editiones.org/tei-publisher/generator/config";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $config:webcomponents := "[[$script?webcomponents]]";
declare variable $config:webcomponents-cdn := "[[$script?cdn]]";
declare variable $config:fore := "[[$script?fore]]";

declare variable $config:default-view := "[[$defaults?view]]";
declare variable $config:default-template := "[[$defaults?template]]";
declare variable $config:default-media := ([[string-join($defaults?media?* ! ('"' || . || '"'), ", ")]]);
declare variable $config:search-default := "[[$indexing?tei?search]]";
declare variable $config:sort-default := "[[$features?browse?sort?default]]";

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

[% if map:contains($defaults, "register-root") %]
    [% if starts-with($defaults?register-root, "/") %]
    declare variable $config:register-root := "[[$defaults?register-root]]";
    [% else %]
    declare variable $config:register-root := $config:data-root || "/[[$defaults?register-root]]";
    [% endif %]
[% else %]
    declare variable $config:register-root := $config:data-root || "/registers";
[% endif %]

declare variable $config:data-exclude := (
    [[ string-join($defaults?data-exclude?*, ",&#10;    ") ]]
);

declare variable $config:odd-root := $config:app-root || "/[[$defaults?odd-root]]";
declare variable $config:default-odd := "[[$defaults?odd]]";
declare variable $config:odd-internal := 
    ( [[ string-join($defaults?odd-internal?* ! ('"' || . || '"'), ", ") ]] );

declare variable $config:odd-available :=
[% block config-odd-available %]
( [[string-join($odds?*[not(. = $defaults?odd-internal?*)] ! ('"' || . || '"'), ", ")]] )
[% endblock %];

declare variable $config:odd-media := ([[string-join($defaults?media?* ! ('"' || . || '"'), ", ")]]);

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

declare variable $config:context-path :=
    [% if map:contains($defaults, "context-path") %]
    "[[ $defaults?context-path ]]"
    [% else %]
    let $prop := util:system-property("teipublisher.context-path")
    return
        if (exists($prop)) then
            if ($prop = "auto") then
                request:get-context-path() || substring-after($config:app-root, "/db") 
            else
                $prop
        else if (exists(request:get-header("X-Forwarded-Host")))
            then ""
        else
            request:get-context-path() || substring-after($config:app-root, "/db")
    [% endif %]
;

(:~
 : Use the JSON configuration to determine which configuration applies for which collection
 :)
declare function config:collection-config($collection as xs:string?, $docUri as xs:string?) {
    [% if exists($context?collection-config) %]
    switch ($collection)
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