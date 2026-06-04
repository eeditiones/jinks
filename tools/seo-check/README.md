# SEO / indexability checker

A Playwright-based checker that measures how indexable TEI Publisher document
pages are. Document content is rendered client-side by `<pb-view>` (it fetches
HTML fragments from the API) and pagination is driven by JS events, so a plain
crawler sees very little. This tool quantifies exactly that.

## How it works

For each page it compares three views:

1. **Raw** — the served HTML parsed with JavaScript **disabled** (what a
   non-rendering crawler / link unfurler sees).
2. **Rendered** — the DOM after the web components load and run, with text
   collected through open shadow roots (what a JS-rendering crawler such as
   Googlebot sees on first load, following links only).
3. **Server** — the fragment `next`-chain walked directly through
   `api/parts/{doc}/json` (ground-truth total content in the document).

It also navigates forward with the keyboard (ArrowRight, which `pb-navigation`
listens for) to show how much content is reachable only by interaction.

## Checks

- `js-only-content` — content present after render but absent in raw HTML
- `pagination-unreachable` — fragments reachable by links vs by JS navigation
- `title`, `title-unique` — present, non-trivial, page-specific
- `lang` — present, matches `--expect-lang`, not the static `#language-default`
- `description`, `canonical`, `open-graph`, `structured-data`
- `h1`, `img-alt`, `robots-meta`
- site-level: `robots-txt`, `sitemap`

## Usage

```bash
cd tools/seo-check
npm install            # installs Playwright + Chromium

node seo-check.mjs --expect-lang en doc/quickstart.xml doc/documentation.xml
```

Options:

| Option | Description |
| --- | --- |
| `--base <url>` | App root URL (default `http://localhost:8080/exist/apps/tei-publisher`) |
| `--out <file>` | Write the full JSON report to `<file>` |
| `--expect-lang <l>` | Flag pages whose `<html lang>` differs from `<l>` |
| `--max-pages <n>` | Max fragments to follow per document (default 200) |

Paths are document paths relative to the app root, e.g. `doc/quickstart.xml`.
With no paths, a small default set is used.

Exit code is non-zero if any page has a FAIL-level finding, so it can gate CI.
