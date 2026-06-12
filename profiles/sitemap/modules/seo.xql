module namespace seo = "http://tei-publisher.org/seo";

import module namespace config = "http://www.tei-c.org/tei-simple/config" at "../../config.xqm";

declare %public function seo:canonical-link ($context as map(*)) as xs:string? {
  (: Path of the current request relative to the application root, e.g.
   : "/doc/quickstart.xml". We derive it from request:get-uri(), which is
   : path-only and always carries the servlet context + app collection prefix.
   : Unlike request:get-url(), it is unaffected by how scheme/host/port are
   : reported behind a reverse proxy, so the path is never dropped. :)
  let $appPrefix := request:get-context-path() || "/apps/" ||
    substring-after($config:app-root, repo:get-root())
  let $url := substring-after(request:get-uri(), $appPrefix)

  (: Public base of the application. A configured production base-uri wins;
   : otherwise reconstruct origin + context-path from the request, omitting the
   : default port so it matches the URL the client actually requested. :)
  let $baseUri :=
    if (exists($context?features?sitemap?base-uri)) then
      $context?features?sitemap?base-uri
    else
      let $port := request:get-server-port()
      let $portPart := if ($port = (80, 443)) then "" else ":" || $port
      return
        request:get-scheme() || "://" || request:get-server-name() ||
        $portPart || $config:context-path

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
