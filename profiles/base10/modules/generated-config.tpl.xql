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

[% if map:contains($context, "data") %]
    [% if starts-with($context?data, "/") %]
    declare variable $config:data-root := "[[$context?data]]";
    [% else %]
    declare variable $config:data-root := $config:app-root || "/[[$context?data]]";
    [% endif %]
[% else %]
    declare variable $config:data-root := $config:app-root || "/data";
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