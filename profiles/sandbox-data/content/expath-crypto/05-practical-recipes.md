# Practical Recipes

This chapter shows real-world patterns that combine the crypto functions for common tasks.

## OAuth 1.0 Signature Base String

OAuth 1.0 uses HMAC-SHA1 to sign API requests. Here's how to construct and sign an OAuth signature base string:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $method := "GET"
let $url := "https://api.example.com/1/resource"
let $params := string-join((
    "oauth_consumer_key=dpf43f3p2l4k3l03",
    "oauth_nonce=kllo9940pd9333jh",
    "oauth_signature_method=HMAC-SHA1",
    "oauth_timestamp=1191242096",
    "oauth_token=nnch734d00sl2jdk",
    "oauth_version=1.0",
    "size=original"
), "&amp;")

let $base-string := string-join(($method, encode-for-uri($url), encode-for-uri($params)), "&amp;")
let $signing-key := "kd94hf93k423kf44&amp;pfkkdhi9sl3r4s00"

let $signature := crypto:hmac($base-string, $signing-key, "SHA1")

return
    <oauth>
        <base-string>{$base-string}</base-string>
        <signature>{$signature}</signature>
    </oauth>
```

The signature is Base64-encoded by default, which is what OAuth 1.0 expects.

## Webhook Signature Verification

Many services (GitHub, Stripe, Slack) sign webhook payloads with HMAC. Here's how to verify:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

(: Simulated webhook payload and signature :)
let $payload := '{"event":"payment.completed","amount":9999}'
let $webhook-secret := "whsec_test_secret_key_12345"

(: Compute the expected signature :)
let $expected := concat("sha256=", crypto:hmac($payload, $webhook-secret, "SHA256", "hex"))

(: In production, $received would come from the X-Hub-Signature-256 header :)
let $received := $expected

return
    <webhook-verification>
        <expected>{$expected}</expected>
        <received>{$received}</received>
        <valid>{$expected = $received}</valid>
    </webhook-verification>
```

Always use constant-time comparison in production to prevent timing attacks.

## API Key Derivation

Derive per-resource API keys from a master secret using HMAC:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $master-secret := "master-key-do-not-share-2026"

for $resource in ("users", "orders", "payments", "admin")
let $derived-key := crypto:hmac($resource, $master-secret, "SHA256", "hex")
return
    <api-key resource="{$resource}">{substring($derived-key, 1, 32)}</api-key>
```

Each resource gets a unique, deterministic key derived from the master secret.

## Encrypting Sensitive Configuration

Store sensitive values (API keys, passwords) encrypted in the database:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $encryption-key := "0123456789abcdef"  (: In production, load from environment :)

(: Encrypt sensitive config values :)
let $config :=
    <config>
        <database-password>{
            crypto:encrypt("super-secret-db-pass", "symmetric", $encryption-key, "AES")
        }</database-password>
        <api-key>{
            crypto:encrypt("sk_live_abc123def456", "symmetric", $encryption-key, "AES")
        }</api-key>
    </config>

(: Later, decrypt when needed :)
return
    <decrypted>
        <database-password>{
            crypto:decrypt(
                xs:base64Binary($config/database-password),
                "symmetric", $encryption-key, "AES")
        }</database-password>
        <api-key>{
            crypto:decrypt(
                xs:base64Binary($config/api-key),
                "symmetric", $encryption-key, "AES")
        }</api-key>
    </decrypted>
```

## Token Generation

Generate secure, URL-safe tokens by combining HMAC with a counter or timestamp:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $server-secret := "token-signing-key-2026"

(: Generate tokens for different purposes :)
for $purpose in ("session", "password-reset", "email-verify")
let $payload := concat($purpose, "|", current-dateTime(), "|", util:uuid())
let $token := crypto:hmac($payload, $server-secret, "SHA256", "hex")
return
    <token purpose="{$purpose}"
           expires="2026-03-21T00:00:00Z"
           value="{substring($token, 1, 40)}"/>
```

## Integrity Check for Stored Documents

Compute an HMAC over a serialized document to detect unauthorized modifications:

```xquery
import module namespace crypto = "http://expath.org/ns/crypto";

let $doc := <invoice id="INV-2026-001">
    <customer>Acme Corp</customer>
    <amount currency="EUR">1500.00</amount>
    <date>2026-03-20</date>
</invoice>

let $integrity-key := "document-integrity-key"
let $serialized := serialize($doc)
let $checksum := crypto:hmac($serialized, $integrity-key, "SHA256", "hex")

return
    <protected-document>
        {$doc}
        <integrity checksum="{$checksum}" algorithm="HMAC-SHA256"/>
    </protected-document>
```

Store the checksum alongside the document. To verify integrity later, recompute the HMAC and compare.
