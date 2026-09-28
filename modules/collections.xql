xquery version "3.1";

(:~
 : Collection and resource operations shared by the /api/collections endpoints.
 : Functions return plain maps; HTTP responses are left to the caller.
 :)
module namespace coll="http://tei-publisher.com/jinks/collections";

declare function coll:list-contents($collection as xs:string, $filter as xs:string?) as xs:string* {
    let $subcollections :=
        for $child in xmldb:get-child-collections($collection)
        let $collpath := concat($collection, "/", $child)
        where sm:has-access(xs:anyURI($collpath), "r")
        return
            concat("/", $child)
    let $resources :=
        for $r in xmldb:get-child-resources($collection)
        where sm:has-access(xs:anyURI(concat($collection, "/", $r)), "r")
        return
            $r
    let $all := if ($filter) then ($subcollections, $resources)[contains(., $filter)] else ($subcollections, $resources)
    for $resource in $all
    order by $resource collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
    return
        $resource
};

(:~
 : List the contents of a collection.
 :
 : @param $start 1-based index of the first entry
 : @param $end 1-based index after the last entry
 : @param $withParent include a ".." entry for the parent collection
 : @return map with "total" and "items"
 :)
declare function coll:list($collection as xs:string, $filter as xs:string?, $start as xs:integer,
    $endParam as xs:integer, $withParent as xs:boolean) as map(*) {
    let $resources := coll:list-contents($collection, $filter)
    let $count := count($resources) + 1
    let $end := if ($endParam gt $count) then $count else $endParam
    let $subset := subsequence($resources, $start, $end - $start + 1)
    let $parent := $withParent and $start = 1 and $collection != "/db"
    let $items :=
        (
            if ($parent) then
                map {
                    "name": "..",
                    "permissions": "",
                    "owner": "",
                    "group": "",
                    "last-modified": "",
                    "writable": sm:has-access(xs:anyURI($collection), "w"),
                    "isCollection": true(),
                    "key": $collection
                }
            else
                (),
            for $resource in $subset
            let $isCollection := starts-with($resource, "/")
            let $path :=
                if ($isCollection) then
                    concat($collection, $resource)
                else
                    concat($collection, "/", $resource)
            where sm:has-access(xs:anyURI($path), "r")
            order by $resource collation "http://www.w3.org/2013/collation/UCA?numeric=yes"
            return
                let $permissions := sm:get-permissions(xs:anyURI($path))/sm:permission
                let $owner := $permissions/@owner/string()
                let $group := $permissions/@group/string()
                let $lastMod :=
                    let $date :=
                        if ($isCollection) then
                            xmldb:created($path)
                        else
                            xmldb:last-modified($collection, $resource)
                    return
                        if (xs:date($date) = current-date()) then
                            format-dateTime($date, "Today [H00]:[m00]:[s00]")
                        else
                            format-dateTime($date, "[M00]/[D00]/[Y0000] [H00]:[m00]:[s00]")
                let $canWrite := sm:has-access(xs:anyURI($path), "w")
                let $permStr := string($permissions/@mode)
                let $permDisplay :=
                    if ($isCollection) then "c" else "-" ||
                    $permStr ||
                    (if ($permissions/sm:acl/@entries ne "0") then "+" else "")
                return map:merge((
                    map {
                        "name": xmldb:decode-uri(xs:anyURI(if ($isCollection) then substring-after($resource, "/") else $resource)),
                        "permissions": $permDisplay,
                        "owner": $owner,
                        "group": $group,
                        "key": xs:anyURI($path),
                        "last-modified": $lastMod,
                        "writable": $canWrite,
                        "isCollection": $isCollection
                    },
                    if (not($isCollection)) then
                        map { "mime": xmldb:get-mime-type(xs:anyURI($path)) }
                    else
                        ()
                ))
        )
    return
        map {
            "total": count($resources) + (if ($parent) then 1 else 0),
            "items": array { $items }
        }
};

declare function coll:delete-collection($collName as xs:string) as map(*) {
    if (sm:has-access(xs:anyURI($collName), "w")) then
        try {
            let $_ := xmldb:remove($collName)
            return
                map { "status": "ok" }
        } catch * {
            map {
                "status": "fail",
                "item": $collName,
                "message": $err:description
            }
        }
    else
        map {
            "status": "fail",
            "item": $collName,
            "message": "You are not allowed to write to collection " || $collName
        }
};

declare function coll:delete-resource($resource as xs:string) as map(*) {
    let $components := analyze-string($resource, "^(.*)/([^/]+)$")//fn:group/string()
    let $resource-collection := $components[1]
    let $resource-name := $components[2]
    let $canWrite :=
        sm:has-access(xs:anyURI($resource), "w") and
        sm:has-access(xs:anyURI($resource-collection), "w")
    return
        if ($canWrite) then
            try {
                let $_ := xmldb:remove($resource-collection, $resource-name)
                return
                    map { "status": "ok" }
            } catch * {
                map {
                    "status": "fail",
                    "item": $resource,
                    "message": $err:description
                }
            }
        else
            map {
                "status": "fail",
                "item": $resource,
                "message": "You are not allowed to write to resource " || $resource
            }
};

(:~
 : Delete resources or collections. Paths are absolute or relative to $collection.
 :
 : @return one result map per selection, with "status" "ok" or "fail"
 :)
declare function coll:delete($collection as xs:string, $selections as xs:string*) as map(*)* {
    for $selection in $selections
    let $path :=
        if (starts-with($selection, "/")) then
            $selection
        else
            $collection || "/" || $selection
    return
        if (xmldb:collection-available($path)) then
            coll:delete-collection($path)
        else
            coll:delete-resource($path)
};

(:~
 : Rename a resource or collection within $collection. Raises an error on failure.
 :)
declare function coll:rename($collection as xs:string, $resource as xs:string, $newName as xs:string) {
    if (xmldb:collection-available($collection || "/" || $resource)) then
        xmldb:rename($collection || "/" || $resource, $newName)
    else
        xmldb:rename($collection, $resource, $newName)
};

declare %private function coll:mkcol-recursive($collection as xs:string, $components as xs:string*) as xs:string? {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xmldb:create-collection($collection, $components[1]),
            coll:mkcol-recursive($newColl, subsequence($components, 2))
        )[last()]
    else
        ()
};

declare function coll:mkcol($collection as xs:string, $path as xs:string) as xs:string? {
    coll:mkcol-recursive($collection, tokenize($path, "/"))
};

(:~
 : Store $data at $path below $root, creating intermediate collections.
 :
 : @return the path of the stored resource
 :)
declare function coll:store($root as xs:string, $path as xs:string, $data as item()) as xs:string {
    if (matches($path, "/[^/]+$")) then
        let $split := analyze-string($path, "^(.*)/([^/]+)$")//fn:group/string()
        let $newCol := coll:mkcol($root, $split[1])
        return
            xmldb:store($newCol, $split[2], $data)
    else
        xmldb:store($root, $path, $data)
};
