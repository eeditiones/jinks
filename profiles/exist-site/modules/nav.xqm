xquery version "3.1";

(:~
 : Navigation module for eXist-db site apps.
 :
 : Reads the nav items from the Jinks context (defined in config.json)
 : and returns an array of app descriptors for the nav bar template.
 : Only apps that are actually installed are included.
 :)
module namespace nav = "http://exist-db.org/site/nav";

(:~
 : Build the nav bar array from the configured items.
 :
 : @param $items sequence of maps from config.json nav.items
 : @param $context-path the request context path (e.g., "/exist")
 : @return array of maps with title, abbrev, url, active
 :)
declare function nav:apps($items as array(*)?, $context-path as xs:string) as array(*) {
    let $current-uri := request:get-uri()
    let $server-context := request:get-context-path()
    return array {
        if (exists($items)) then
            for $entry in $items?*
            let $abbrev := $entry?abbrev
            let $app-path := $server-context || "/apps/" || $abbrev
            where xmldb:collection-available("/db/apps/" || $abbrev)
            return map {
                "title": $entry?title,
                "abbrev": $abbrev,
                "url": $app-path,
                "active": starts-with($current-uri, $app-path)
            }
        else ()
    }
};
