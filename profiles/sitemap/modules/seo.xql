module namespace seo = "http://tei-publisher.org/seo";

import module namespace config = "http://www.tei-c.org/tei-simple/config" at "../../config.xqm";

declare %public function seo:canonical-link ($context as map(*)) as xs:string? {
  let $baseUriFromRequest := (: Generate from request :) request:get-scheme() ||
    "://" ||
    request:get-server-name() ||
    ":" ||
    request:get-server-port() ||
    request:get-context-path() ||
    "/apps/" ||
    substring-after($config:app-root, repo:get-root())

  (: Step one, replace domain :)
  let $baseUri := if ($context?features?sitemap?base-uri) then (
    $context?features?sitemap?base-uri
  ) else (
    $baseUriFromRequest
  )
  let $pageUrl := request:get-path-info()
  let $querystring := request:get-query-string()
  let $url := substring-after(request:get-url(), $baseUriFromRequest)

  (: Normalize the xml id routing (?id="xxx") to exist node id (?root="1.2.3") :)
  let $normalizedQuerystring :=
    for $param-name in request:get-parameter-names()
    order by $param-name
    return if ($param-name = "id") then (
      let $id := request:get-parameter("id", ())
      let $normalizedRoot := if ($context?doc?content) then (
        id($id, $context?doc?content) => util:node-id()
      ) else (
      )
      return if ($normalizedRoot) then (
        "root=" || $normalizedRoot
      ) else (
        "id=" || $id
      )
    ) else (
      $param-name || "=" || request:get-parameter($param-name, ())
    )

  let $root := request:get-parameter("root", ())

  return $baseUri || $url || "?" || string-join($normalizedQuerystring, "&amp;")
};
