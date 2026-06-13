# SEO root-proxy for local testing

A minimal nginx reverse proxy that serves your locally running TEI Publisher app
from the **site root** on port 80, so SEO artefacts can be tested the way a search
engine would see them:

- `http://localhost/sitemap.xml`
- `http://localhost/robots.txt`
- `<link rel="canonical" href="http://localhost/...">` on document pages

During development the app is served from
`http://localhost:8080/exist/apps/tei-publisher/`. This proxy rewrites the root onto
that collection and injects an `X-Forwarded-Host` header, which makes the app's
`$config:context-path` resolve to an empty string (see
`profiles/base10/modules/generated-config.tpl.xql`). As a result all in-app URLs
become root-relative and resolve correctly through the proxy. **No app rebuild is
required.**

## Prerequisites

1. A TEI Publisher app generated from the `base10` profile **with the `sitemap`
   feature**, running and reachable at
   `http://localhost:8080/exist/apps/tei-publisher/`.

2. That eXist instance must **not** pin the `teipublisher.context-path` system
   property (a plain dev eXist with jinks synced does not — so you're fine). If it is
   pinned to `auto` or a fixed value, the root mapping won't take effect.

3. For correct SEO output, set `features.sitemap.base-uri` to `http://localhost` in the
   generated app's `context.json`. This drives:
   - the canonical links produced by `seo:canonical-link`,
   - the `<loc>` entries written into `sitemap.xml`,
   - the `Sitemap:` line in `robots.txt`.

   This is an **app-generation** setting (configured via jinks-cli when generating the
   app); the proxy cannot inject it.

## Usage

```bash
docker compose -f profiles/sitemap/tools/docker-compose.yml up -d
```

Generate the sitemap once (it is crawled on demand and stored):

```bash
curl -s -X POST http://localhost/api/actions/sitemap
```

Then verify:

```bash
curl -sI http://localhost/                 # 200, landing page
curl -s  http://localhost/api/documents     # API reachable through the root
curl -s  http://localhost/sitemap.xml        # <loc>http://localhost/...</loc> entries
curl -s  http://localhost/robots.txt         # contains "Sitemap: http://localhost/sitemap.xml"
```

Open a document page in a browser and confirm the `<link rel="canonical">` points at
`http://localhost/...`.

Tear down:

```bash
docker compose -f profiles/sitemap/tools/docker-compose.yml down
```

## Notes

- nginx-only: the running eXist is treated as an external upstream on the Docker host
  (`host.docker.internal:8080`).
- If your app was generated under a different abbrev than `tei-publisher`, edit the
  `proxy_pass` and `proxy_redirect` paths in `nginx.conf`.
- Port 80 must be free on the host (stop any other web server first).
