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

  (: Replace the request host with the configured production base uri, if any. :)
  let $baseUri := head(($context?features?sitemap?base-uri, $baseUriFromRequest))

  (: Path portion only (request:get-url has no query string). :)
  let $url := substring-after(request:get-url(), $baseUriFromRequest)

  (: Canonical = path + the stable fragment identifier only. We keep the
   : persistent "id" (xml:id) rather than normalizing it to a volatile eXist
   : node id, so the canonical matches the URL the sitemap emits and survives
   : reindexing. Other parameters (odd, view, lang, …) are dropped so they do
   : not spawn duplicate canonicals. "root" is kept only as a fallback for
   : documents that have no xml:id. :)
  let $id := request:get-parameter("id", ())
  let $root := request:get-parameter("root", ())
  let $fragment :=
    if (string-length(normalize-space($id)) gt 0) then
      "?id=" || encode-for-uri($id)
    else if (string-length(normalize-space($root)) gt 0) then
      "?root=" || encode-for-uri($root)
    else
      ""

  return $baseUri || $url || $fragment
};
