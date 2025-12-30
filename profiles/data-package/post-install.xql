xquery version "3.0";

declare namespace repo="http://exist-db.org/xquery/repo";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare variable $repoxml :=
    let $uri := doc($target || "/expath-pkg.xml")/*/@name
    let $repo := util:binary-to-string(repo:get-resource($uri, "repo.xml"))
    return
        parse-xml($repo)
;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            if (not(xmldb:collection-available($collection || "/" || $components[1]))) then
                let $created := xmldb:create-collection($collection, $components[1])
                return (
                    sm:chown(xs:anyURI($created), $repoxml//repo:permissions/@user),
                    sm:chgrp(xs:anyURI($created), $repoxml//repo:permissions/@group),
                    sm:chmod(xs:anyURI($created), replace($repoxml//repo:permissions/@mode, "(..).(..).(..).", "$1x$2x$3x"))
                )
            else
                (),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:create-data-collection() {
    if (xmldb:collection-available($target || "/data")) then
        ()
    else
        local:mkcol($target, "data")
};

local:create-data-collection()