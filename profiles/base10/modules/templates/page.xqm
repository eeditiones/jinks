xquery version "3.1";

module namespace page="http://teipublisher.com/ns/templates/page";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

declare namespace expath="http://expath.org/ns/pkg";

declare variable $page:EXIDE :=
    let $pkg := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    let $appLink :=
        if ($pkg) then
            substring-after(util:collection-name($pkg), repo:get-root())
        else
            ()
    let $path := string-join((request:get-context-path(), request:get-attribute("$exist:prefix"), $appLink, "index.html"), "/")
    return
        replace($path, "/+", "/");

declare function page:system() {
    map {
        "publisher": $config:expath-descriptor/@version/string(),
        "api": json-doc($config:app-root || "/modules/lib/api.json")?info?version
    }
};

declare function page:parameter($context as map(*), $name as xs:string) {
    page:parameter($context, $name, ())
};

(:~
 : Get a parameter from the request. Return the default value if the parameter
 : is not present.
 :)
declare function page:parameter($context as map(*), $name as xs:string, $default as item()*) {
    let $reqParam := head(($context?request?parameters?($name), request:get-parameter($name, ())))
    return
        if (exists($reqParam)) then
            $reqParam
        else
            $default
};

(:~
 : Generate a breadcrumb trail for the current collection.
 :)
declare function page:collection-breadcrumbs($context as map(*)) {
    if (exists($context?doc)) then
        let $components := config:get-relpath($context?doc?content, $config:data-default) => tokenize("/")
        return
            if (count($components) = 1) then
                <li>
                    <a href="{$context?context-path}/browse.html?collection=">
                        <pb-i18n key="breadcrumb.document-root">
                            Home
                        </pb-i18n>
                    </a>
                </li>
            else
                for $i in 1 to count($components) - 1
                return
                    <li>
                        <a href="{$context?context-path}/browse.html?collection={string-join(subsequence($components, 1, $i), '/')}">
                            <pb-i18n key="breadcrumb.{string-join(subsequence($components, 1, $i), '.')}">
                                {$components[$i]}
                            </pb-i18n>
                        </a>
                    </li>
    else ()
};
