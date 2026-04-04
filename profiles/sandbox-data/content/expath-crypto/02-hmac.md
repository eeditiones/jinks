# HMAC Authentication

HMAC (Hash-based Message Authentication Code) is the workhorse of API authentication. It combines a secret key with a message to produce a fixed-size authentication tag. If the sender and receiver share the same key, the receiver can verify that the message hasn't been tampered with.

## Basic HMAC

The simplest form takes data, a key, and an algorithm. The default output is Base64-encoded:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

crypto:hmac("Hello, World!", "my-secret-key", "SHA256")
```

The result is a Base64 string. The same inputs always produce the same output — but changing even one character of the data or key produces a completely different result.

## Hex Output

For APIs that expect hex-encoded HMACs, pass `"hex"` as the fourth argument:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

crypto:hmac("Hello, World!", "my-secret-key", "SHA256", "hex")
```

The hex output is a string of lowercase hexadecimal characters — 64 characters for SHA256, 40 for SHA1, 128 for SHA512.

## Comparing Algorithms

Different algorithms produce different output lengths. Here we compare all five supported algorithms:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $data := "test message"
let $key := "secret"
for $alg in ("MD5", "SHA1", "SHA256", "SHA384", "SHA512")
return
    <hmac algorithm="{$alg}"
          hex-length="{string-length(crypto:hmac($data, $key, $alg, 'hex'))}"
          value="{crypto:hmac($data, $key, $alg, 'hex')}"/>
```

SHA256 is the most commonly used for modern APIs. MD5 and SHA1 are supported for legacy compatibility but are considered weak.

## Verifying an HMAC

To verify a message, compute the HMAC with the shared key and compare it to the expected value:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $message := "amount=100&amp;currency=USD&amp;timestamp=2026-03-20T12:00:00Z"
let $shared-secret := "webhook-signing-key-abc123"

(: Compute the expected HMAC :)
let $computed := crypto:hmac($message, $shared-secret, "SHA256", "hex")

(: The sender provided this HMAC :)
let $received := crypto:hmac($message, $shared-secret, "SHA256", "hex")

return
    <verification>
        <computed>{$computed}</computed>
        <received>{$received}</received>
        <valid>{$computed = $received}</valid>
    </verification>
```

In practice, the `$received` value would come from an HTTP header (e.g., `X-Signature`).

## Key Sensitivity

Changing the key by even one character produces a completely different HMAC — this is what makes HMAC secure:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $data := "same data"
for $key in ("key-1", "key-2", "key-3")
return
    <result key="{$key}">{crypto:hmac($data, $key, "SHA256", "hex")}</result>
```

An attacker who doesn't know the key cannot forge a valid HMAC, even if they know the data.
