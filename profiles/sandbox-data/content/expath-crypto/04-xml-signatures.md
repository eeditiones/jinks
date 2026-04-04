# XML Digital Signatures

XML Digital Signatures (XML DSIG) provide integrity, authentication, and non-repudiation for XML documents. The `crypto:generate-signature` function signs a document, and `crypto:validate-signature` verifies it.

## Signing a Document

The `generate-signature` function takes six arguments: the document, canonicalization method, digest algorithm, signature algorithm, namespace prefix, and signature type:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <order id="12345">
    <item sku="A001" qty="2">Widget</item>
    <total currency="USD">49.98</total>
</order>

return crypto:generate-signature(
    $doc,
    "inclusive",          (: canonicalization :)
    "SHA256",            (: digest algorithm :)
    "RSA_SHA256",        (: signature algorithm :)
    "dsig",              (: namespace prefix :)
    "enveloped"          (: signature type :)
)
```

The result is the original document with a `<dsig:Signature>` element appended. A fresh RSA key pair is generated for each signature.

## Examining the Signature

The signature element contains the signed info, signature value, and public key:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <message>Hello</message>
let $signed := crypto:generate-signature($doc, "inclusive", "SHA256", "RSA_SHA256", "dsig", "enveloped")

return
    <analysis>
        <has-signature>{exists($signed//*[local-name() = 'Signature'])}</has-signature>
        <has-signed-info>{exists($signed//*[local-name() = 'SignedInfo'])}</has-signed-info>
        <has-key-info>{exists($signed//*[local-name() = 'KeyInfo'])}</has-key-info>
        <digest-method>{$signed//*[local-name() = 'DigestMethod']/@Algorithm/string()}</digest-method>
        <signature-method>{$signed//*[local-name() = 'SignatureMethod']/@Algorithm/string()}</signature-method>
    </analysis>
```

## Canonicalization Options

XML canonicalization normalizes the document before hashing to ensure that semantically equivalent XML produces the same digest. Four methods are supported:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <root><data>test</data></root>
for $c14n in ("inclusive", "inclusive-with-comments", "exclusive", "exclusive-with-comments")
return
    <method name="{$c14n}">
        {
            let $signed := crypto:generate-signature($doc, $c14n, "SHA256", "RSA_SHA256", "dsig", "enveloped")
            return
                <signed-ok>{exists($signed//*[local-name() = 'Signature'])}</signed-ok>
        }
    </method>
```

- **inclusive**: The most common choice. Includes the namespace context of the parent.
- **exclusive**: Better for documents that will be embedded in different contexts.

## Digest Algorithms

The digest algorithm determines the hash function used to compute the document digest:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <root><data>test</data></root>
for $digest in ("SHA1", "SHA256", "SHA512")
let $signed := crypto:generate-signature($doc, "inclusive", $digest, "RSA_SHA256", "dsig", "enveloped")
return
    <digest algorithm="{$digest}"
            method="{$signed//*[local-name() = 'DigestMethod']/@Algorithm/string()}"/>
```

SHA256 is recommended. SHA1 is available for legacy compatibility.
