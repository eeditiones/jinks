# Cryptographic Hashing

A cryptographic hash function takes input data and produces a fixed-size "fingerprint." The same input always produces the same hash, but even a tiny change in the input produces a completely different result. Hashes are one-way — you cannot recover the original data from a hash.

> **Note:** eXist-db 7.0 also provides `fn:hash()` as part of XQuery 4.0 and `util:hash()` as a built-in. For new code, either of those is fine. `crypto:hash()` is part of the EXPath Cryptographic Module spec and is provided for backward compatibility and cross-engine portability (BaseX also implements it).

## Basic Hash

The simplest form takes data and an algorithm. The default output is Base64-encoded:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

crypto:hash("Hello, World!", "SHA-256")
```

## Hex Output

For hex-encoded output, pass `"hex"` as the third argument:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

crypto:hash("Hello, World!", "SHA-256", "hex")
```

## Comparing Algorithms

Five algorithms are supported, producing different output lengths:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

for $alg in ("MD5", "SHA-1", "SHA-256", "SHA-384", "SHA-512")
return
    <hash algorithm="{$alg}"
          hex-length="{string-length(crypto:hash('test', $alg, 'hex'))}"
          value="{crypto:hash('test', $alg, 'hex')}"/>
```

SHA-256 is the most widely used. MD5 and SHA-1 are considered weak for security purposes but are still useful for checksums and legacy compatibility.

## Hashing Nodes

You can hash XML nodes directly — the string value of the node is hashed:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <order id="123"><total>99.99</total></order>
return crypto:hash($doc, "SHA-256", "hex")
```

## Verifying Data Integrity

Hashes are commonly used to verify that data hasn't been corrupted or tampered with:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $original := "The quick brown fox jumps over the lazy dog"
let $expected-hash := crypto:hash($original, "SHA-256", "hex")

(: Later, verify the data is unchanged :)
let $received := "The quick brown fox jumps over the lazy dog"
let $actual-hash := crypto:hash($received, "SHA-256", "hex")

return
    <integrity-check>
        <expected>{$expected-hash}</expected>
        <actual>{$actual-hash}</actual>
        <match>{$expected-hash = $actual-hash}</match>
    </integrity-check>
```

## Comparison with fn:hash

eXist-db 7.0 with XQuery 4.0 support also provides `fn:hash()` as a built-in. Both produce the same digest:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $crypto-hash := crypto:hash("test", "SHA-256", "hex")
let $fn-hash := string(fn:hash("test", "SHA-256"))
return
    <comparison>
        <crypto-hash>{$crypto-hash}</crypto-hash>
        <fn-hash>{$fn-hash}</fn-hash>
        <same-digest>{upper-case($crypto-hash) = $fn-hash}</same-digest>
    </comparison>
```

The key difference: `crypto:hash()` returns `xs:string` (base64 or hex encoded), while `fn:hash()` returns `xs:hexBinary`. Use whichever fits your codebase — `crypto:hash()` for EXPath portability, `fn:hash()` for standard XQuery 4.0.
