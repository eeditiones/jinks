xquery version "3.1";

module namespace jt="http://teipublisher.com/api/jinntap";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace router="http://e-editiones.org/roaster";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $jt:new-doc :=
    <TEI xmlns="http://www.tei-c.org/ns/1.0">
   <teiHeader>
      <fileDesc>
         <titleStmt>
            <title>JinnTap Documentation</title>
         </titleStmt>
         <publicationStmt>
            <p>Information about publication or distribution</p>
         </publicationStmt>
         <sourceDesc>
            <p>Information about the source</p>
         </sourceDesc>
      </fileDesc>
   </teiHeader>
   <text>
      <body>
         <div>
            <p></p>
         </div>
      </body>
   </text>
</TEI>;

declare function jt:load($request as map(*)) {
    let $id := $request?parameters?id
    let $doc := config:get-document($id)
    let $xml :=
        if (not($doc//tei:body)) then
            $doc//tei:text/tei:div
        else
            $doc//tei:body
    return (
        jt:load-xml($xml, false()),
        <tei-listAnnotation>
        { 
            jt:load-xml($doc//tei:listAnnotation/tei:note, true()),
            jt:load-xml($xml//tei:note, true())
        }
        </tei-listAnnotation>
    )
};

declare %private function jt:load-xml($nodes as node()*, $importNotes as xs:boolean) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(tei:note) return
                if ($importNotes) then
                    <tei-note target="#{generate-id($node)}" type="note">
                        { jt:load-xml($node/node(), false()) }
                    </tei-note>
                else
                    <tei-anchor id="{generate-id($node)}"/>
            case element() return
                element { "tei-" || local-name($node) } {
                    $node/@* except $node/@xml:id,
                    if ($node/@xml:id) then
                        attribute id { $node/@xml:id }
                    else
                        (),
                    jt:load-xml($node/node(), $importNotes)
                }
            default return
                $node
};

declare function jt:save($request as map(*)) {
    let $id := $request?parameters?id
    let $doc := config:get-document($id)
    let $doc := 
        if ($doc) then 
            $doc 
        else 
            jt:create-new($jt:new-doc, $request?parameters?title)
    let $body := $request?body
    let $xml := jt:save-xml($doc, $body)
    let $_ := xmldb:store($config:data-default, $id, $xml)
    return
        router:response(200, "application/json", map {
            "status": "ok"
        })
};

declare function jt:save-xml($nodes as node()*, $input as document-node()) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document {
                    jt:save-xml($node/node(), $input)
                }
            case element(tei:TEI) return
                element { node-name($node) } {
                    $node/@*,
                    $node/tei:teiHeader,
                    if (not($node/tei:standOff)) then
                        <standOff>{ $input//tei:listAnnotation }</standOff>
                    else
                        (),
                    jt:save-xml($node/tei:text, $input)
                }
            case element(tei:standOff) return
                element { node-name($node) } {
                    $node/@*,
                    $node/* except $node/tei:listAnnotation,
                    $input//tei:listAnnotation
                }
            case element(tei:body) return
                element { node-name($node) } {
                    $node/@*,
                    $input/tei:body/node() except $input/tei:body/tei:listAnnotation
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    jt:save-xml($node/node(), $input)
                }
            default return
                $node
};

declare function jt:create-new($nodes as node()*, $title as xs:string) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(tei:title) return
                element { node-name($node) } {
                    $node/@*,
                    $title
                }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    jt:create-new($node/node(), $title)
                }
            default return
                $node
};
