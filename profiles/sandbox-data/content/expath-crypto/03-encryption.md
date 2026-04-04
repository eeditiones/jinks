# Symmetric Encryption

Symmetric encryption uses the same key to encrypt and decrypt data. The `crypto:encrypt` and `crypto:decrypt` functions implement AES and DES encryption with CBC mode and PKCS5 padding.

## AES Encrypt and Decrypt

AES (Advanced Encryption Standard) is the most widely used symmetric cipher. It requires a key of 16, 24, or 32 bytes:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $key := "0123456789abcdef"  (: 16 bytes = AES-128 :)
let $plaintext := "This is a secret message"

let $encrypted := crypto:encrypt($plaintext, "symmetric", $key, "AES")
let $decrypted := crypto:decrypt($encrypted, "symmetric", $key, "AES")

return
    <result>
        <original>{$plaintext}</original>
        <encrypted>{$encrypted}</encrypted>
        <decrypted>{$decrypted}</decrypted>
        <round-trip-ok>{$plaintext = $decrypted}</round-trip-ok>
    </result>
```

The encrypted output is `xs:base64Binary`. A random initialization vector (IV) is automatically generated and prepended to the ciphertext.

## Random IV

Each encryption produces different ciphertext, even for the same plaintext and key, because a fresh random IV is generated each time:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $key := "0123456789abcdef"
let $msg := "same message"
return
    <randomness>
        <attempt1>{crypto:encrypt($msg, "symmetric", $key, "AES")}</attempt1>
        <attempt2>{crypto:encrypt($msg, "symmetric", $key, "AES")}</attempt2>
        <note>These two values should differ (random IV)</note>
    </randomness>
```

This property (semantic security) means an attacker cannot tell if two ciphertexts encrypt the same plaintext.

## AES Key Sizes

AES supports three key sizes. Longer keys provide more security:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $msg := "test"
for $key in (
    "0123456789abcdef",                  (: 16 bytes = AES-128 :)
    "0123456789abcdef01234567",          (: 24 bytes = AES-192 :)
    "0123456789abcdef0123456789abcdef"   (: 32 bytes = AES-256 :)
)
let $enc := crypto:encrypt($msg, "symmetric", $key, "AES")
let $dec := crypto:decrypt($enc, "symmetric", $key, "AES")
return
    <result key-bytes="{string-length($key)}" ok="{$dec = $msg}"/>
```

AES-256 (32-byte key) is recommended for sensitive data.

## DES Encryption

DES (Data Encryption Standard) uses an 8-byte key. It is included for legacy compatibility but AES is preferred for new applications:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $key := "12345678"  (: exactly 8 bytes for DES :)
let $msg := "legacy system data"

let $enc := crypto:encrypt($msg, "symmetric", $key, "DES")
let $dec := crypto:decrypt($enc, "symmetric", $key, "DES")

return
    <result>
        <decrypted>{$dec}</decrypted>
        <ok>{$dec = $msg}</ok>
    </result>
```

## Encrypting Unicode Text

The encryption functions handle Unicode text correctly — the data is internally encoded as UTF-8 before encryption:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $key := "0123456789abcdef"
let $msg := "Sch&#xF6;ne Gr&#xFC;&#xDF;e aus &#xD6;sterreich"

let $enc := crypto:encrypt($msg, "symmetric", $key, "AES")
let $dec := crypto:decrypt($enc, "symmetric", $key, "AES")

return
    <result>
        <original>{$msg}</original>
        <decrypted>{$dec}</decrypted>
        <ok>{$dec = $msg}</ok>
    </result>
```

## Wrong Key Detection

Decrypting with the wrong key raises an error — the padding check fails because the decrypted bytes are garbage:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $enc := crypto:encrypt("secret", "symmetric", "0123456789abcdef", "AES")
return
    try {
        crypto:decrypt($enc, "symmetric", "fedcba9876543210", "AES")
    } catch * {
        <error code="{$err:code}">{$err:description}</error>
    }
```
