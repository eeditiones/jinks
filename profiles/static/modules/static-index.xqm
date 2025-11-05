xquery version "3.1";

module namespace idx="http://tei-publisher.com/jinks/static/index";

import module namespace nlp="http://teipublisher.com/api/nlp" at "lib/api/nlp.xqm";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace pm-config="http://www.tei-c.org/tei-simple/pm-config" at "pm-config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare function idx:entry($request as map(*)) {
    let $path := xmldb:decode($request?parameters?id)
    let $pathPrefix := head(($request?parameters?prefix, "documents"))
    let $doc := config:get-document($path)/tei:TEI
    let $root := if (ends-with($config:data-default, "/")) then $config:data-default else $config:data-default || "/"
    return [
        map {
            "content": nlp:extract-plain-text($doc//tei:text, true()) => string-join(),
            "commentary": nlp:extract-plain-text($doc//tei:text//tei:note, false()) => string-join(),
            "title": nlp:extract-plain-text($doc//tei:titleStmt, false()) => string-join(),
            "link": $pathPrefix || "/" || substring-after(document-uri(root($doc)), $root) || "/1/index.html"
        }
    ]
};

declare %private function idx:get-next-page ($config, $div) {
  let $next-page := $config:next-page($config, $div, 'div')
  return if ($next-page) then ($div, idx:get-next-page($config, $next-page)) else $div
};

declare function idx:get-all-parts($config, $doc) {
  idx:get-next-page($config, $doc/descendant-or-self::tei:div[1])
};

declare function idx:entry-part($request as map(*)) {
    array {
        let $path := xmldb:decode($request?parameters?id)
        let $doc := config:get-document($path)/tei:TEI
        let $config := tpu:parse-pi(root($doc), ())
        let $pathPrefix := head(($request?parameters?prefix, "documents"))
        let $root := if (ends-with($config:data-default, "/")) then $config:data-default else $config:data-default || "/"
        for $div at $i in idx:get-all-parts($config, $doc)
        return
            map {
                "content": nlp:extract-plain-text($div, true()) => string-join(),
                "commentary": nlp:extract-plain-text($div//tei:note, false()) => string-join(),
                "title": nlp:extract-plain-text($div/tei:head, false()) => string-join(),
                "link": $pathPrefix || "/" || substring-after(document-uri(root($doc)), $root) || "/" || $i || "/index.html"
            }
    }
};