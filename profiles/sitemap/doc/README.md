## Sitemap and SEO

This feature helps search engines discover and index the public pages of a TEI Publisher application. It generates a [sitemap](https://www.sitemaps.org/) listing every document URL and paginated fragment, adds `<link rel="canonical">` tags to HTML pages, and ships a `robots.txt` that points crawlers at the sitemap while excluding internal paths.

Together, these artefacts address common SEO requirements for scholarly editions: crawlers receive a complete URL list, duplicate URLs with varying query parameters collapse to a single canonical, and administrative or data paths are kept out of the index.

**Note**: crawlers expect `sitemap.xml` as well as `robots.txt` to be served from the root of a webserver. You'll therefore need a proxy in front of eXist-db, which rewrites URLs to point to exactly one jinks-generated application (see remarks on _local testing_ below).

### Features

1. **Sitemap generation** — crawl all documents in the application and write a standards-compliant `sitemap.xml` (one `<url>` entry per page/fragment).
2. **Canonical URLs** — inject a `<link rel="canonical">` into every HTML page via `templates/seo-blocks.html` and `modules/seo.xql`.
3. **`robots.txt`** — generated from `robots.tpl.txt` at app build time; disallows internal collections and, when configured, declares the sitemap location.
4. **Jinks action** — a _Sitemap_ button in the _Actions_ toolbar triggers regeneration after content changes.

### SEO in context

| Mechanism | Purpose |
|-----------|---------|
| `sitemap.xml` | Tells search engines which URLs exist and should be crawled |
| `<link rel="canonical">` | Prevents duplicate-content penalties when the same text is reachable under several query strings |
| `robots.txt` | Blocks indexing of transform output, raw data, modules, print views, and the ODD editor; optionally advertises the sitemap |
| Server-side HTML fragments (`page:content` in base10) | Ensures crawlers that do not execute JavaScript still receive the text of each paginated URL |

For paginated editions, the sitemap therefore lists URLs such as `doc/example.xml?id=chapter-1`. When a crawler requests that URL, the server renders that fragment's content in the initial HTML, matching what users see after the web components load.

### Configuration

Enable the feature by adding the _Sitemap_ profile when generating your application. The default profile configuration includes one custom URL for the landing page:

```json
"features": {
    "sitemap": {
        "custom": [
            "index.html"
        ]
    }
}
```

#### `base-uri`

Set the public origin of your site so canonical links, sitemap `<loc>` entries, and the `Sitemap:` line in `robots.txt` all use the URL search engines should index — not the internal eXist path (`/exist/apps/…`).

```json
"features": {
    "sitemap": {
        "base-uri": "https://edition.example.org"
    }
}
```

This is an **app-generation** setting (written into `context.json`). If omitted, the base URI is derived from each incoming request (scheme, host, port, and context path). That is sufficient for development but usually wrong for production deployments behind a reverse proxy or at a domain different from the eXist servlet path.

#### `custom`

Array of additional relative paths to include in the sitemap beyond those discovered by the crawl — static pages, browse views, or other entry points that are not TEI documents.

```json
"features": {
    "sitemap": {
        "custom": [
            "index.html",
            "browse.html"
        ]
    }
}
```

### Usage

After generating or updating content, regenerate the sitemap: open your application in Jinks and click **Sitemap** in the _Actions_ toolbar.

Then verify:

```bash
curl -s https://edition.example.org/sitemap.xml
curl -s https://edition.example.org/robots.txt
```

Open a document page and confirm the `<link rel="canonical">` in the page source points at the same URL shape as the corresponding `<loc>` in the sitemap.

### Local testing with a root proxy

During development the app typically lives under `/exist/apps/<abbrev>/`, while production SEO artefacts are served from the site root. The demo in `profiles/sitemap/tools/` provides an nginx reverse proxy that maps `http://localhost/` onto your local eXist instance so you can test `sitemap.xml`, `robots.txt`, and canonical links as a crawler would see them. See `profiles/sitemap/tools/README.md` for prerequisites and usage.

For the sitemap to work, you'll also need to set the `base-uri` property as follows:

```json
"features": {
    "sitemap": {
        "base-uri": "http://localhost"
    }
}
```

### API

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/sitemap.xml` | Return the generated sitemap (404 if not yet generated) |
| `POST` | `/api/actions/sitemap` | Crawl the application and store a new `sitemap.xml` |

Both endpoints are defined in `modules/sitemap-api.tpl.json` and implemented in `modules/sitemap.xql`.
