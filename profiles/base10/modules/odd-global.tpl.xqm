xquery version "3.1";

module namespace config="http://e-editiones.org/tei-publisher/odd-global";

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

(:~
 : The root of the collection hierarchy containing data.
 :)
 [% if map:contains($defaults, "data") %]
    [% if starts-with($defaults?data, "/") %]
    declare variable $config:data-root := "[[$defaults?data]]";
    [% else %]
    declare variable $config:data-root := $config:app-root || "/[[$defaults?data]]";
    [% endif %]
[% else %]
    declare variable $config:data-root := $config:app-root || "/data";
[% endif %]

(:~
 : The root of the collection hierarchy containing registers data.
 :)
declare variable $config:register-root := $config:data-root || "/registers";

(:~
 : Addressing method used in the app: by id or not
 :)
[% if map:contains($defaults, "address-by-id") %]
    declare variable $config:address-by-id as xs:boolean := [%if $defaults?address-by-id %] true() [% else %] false() [% endif %];
[% else %]
    declare variable $config:address-by-id := false();
[% endif %]
