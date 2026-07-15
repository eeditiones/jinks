# Distributed Text Services (DTS)

This profile adds a standards-compliant [DTS 1.0 API](https://distributed-text-services.github.io/specifications/) to your TEI Publisher application, enabling external clients to discover, navigate, and retrieve documents using a well-defined REST interface. It also provides a built-in DTS browser page for interactively exploring any DTS-compatible server from within your application.

The profile requires additional configuration in order to provide a meaningful service (see below). For demonstration purposes, the [DTS Blueprint](../../dts-blueprint) is provided, which includes auxiliary data and an ODD to demonstrate how to use DTS to embed passages from external resources (the bible in this case).

## Compliance

The implementation aims to be fully compliant with the 1.0 version of the DTS specification. The profile passes all tests of the [DTS Validator](https://github.com/distributed-text-services/validator). For remaining limitations see below.

## What you get

- **Four DTS endpoints** served under `/api/dts`: Entry Point, Collection, Document, and Navigation.
- A **DTS browser** page (`dts.html`) with collection navigation, pagination, and a raw JSON-LD viewer. Reachable via a *DTS* link added automatically to the navigation menu.
- A **server discovery** helper (`/api/dts/list`) that lists all installed applications exposing a DTS API.
- A **resource import** helper (`/api/dts/import`) for pulling documents from remote DTS servers into the local database.

## Configuration

Collections exposed through the DTS API are configured via the `features.dts.member` array:

```json
"features": {
    "dts": {
        "member": [
            {
                "id": "texts",
                "title": "Primary Texts",
                "type": "collection",
                "path": "texts"
            },
            {
                "id": "letters",
                "title": "Correspondence",
                "type": "collection",
                "path": "letters",
                "dublinCore": {
                    "title": "Letter Collection",
                    "creator": "My Project"
                }
            }
        ]
    }
}
```

### Collection options

| Option | Required | Description |
|--------|----------|-------------|
| `id` | yes | Unique identifier for the collection in the DTS API |
| `title` | yes | Human-readable display title |
| `type` | yes | `collection` for sub-collections, `resource` for individual documents |
| `path` | yes | Path relative to the application's data root |
| `dublinCore` | no | Object with Dublin Core metadata fields (e.g. `title`, `creator`, `description`, `license`) |

In addition to the configured collections, the ODD collection is always exposed automatically under the id `odd`.

## Document endpoint

The `/api/dts/document` endpoint supports content negotiation via the `mediaType` parameter:

| Value | Format |
|-------|--------|
| `application/tei+xml` | TEI/XML (default) |
| `text/html` | HTML rendered via the application's ODD |
| `application/epub+zip` | EPUB |
| `application/pdf` | PDF |
| `text/markdown` | Markdown |

Fragment selection is supported via `ref` (single citable node) or `start`/`end` (inclusive range of sibling nodes).

## DTS Browser

A Javascript-based DTS client: DTS-enabled apps installed on the same eXist-db are detected automatically and appear in the server selection dropdown. If there's only one app installed,the browser connects to it automatically on page load.

You can also add external DTS servers via `config.json`. For example, the _DTS Blueprint_ profile adds the DTS service provided by Heidelberg University library:

```json
"features": {
    "dts": {
        "servers": [
            {
                "entry": "https://digi.ub.uni-heidelberg.de/editionService/dts/",
                "title": "Uni Heidelberg"
            }
        ]
    }
}
```

## Known limitations

The following minor limitations are know and will be addressed:

- **`nav=parents`** on the Collection endpoint returns an incorrect member list.
- **Multiple citation trees** (the `tree` parameter) are defined in the spec but not implemented.
- **Navigation pagination** is not yet functional.

---

## Encoding TEI Documents for the DTS Profile

For guidance on preparing TEI-XML documents so they serve correctly through the DTS API endpoints, see the [TEI Encoding Guide](#tei-encoding-guide) below.

---

# TEI Encoding Guide

How to prepare TEI-XML documents and define collections so they serve correctly
through the **Distributed Text Services (DTS) v1.0 API** provided by this profile
in TEI Publisher 10.

> **Scope and currency.** This guide is based on a reading of the jinks `dts`
> profile source on the `main` branch (profile version `1.0.0`) and the
> [DTS v1.0 specification](https://dtsapi.org/specifications/versions/v1.0/)
> (published 13 February 2026). Behaviour described here reflects the
> implementation, not just the spec — the two differ in places. If you pin a
> tagged release, verify the citation/navigation functions against that tag.

## Limitations
Citation structures are not currently supported (planned for milestone 2) so the current structure is computed such that every div becomes a citableUnit. This will remain the fallback so it will apply if there is no explicit citeStructure.

---

## 1. The core model: citation tree = nested `<div>`, keyed by `@xml:id`

The most important thing to understand before encoding anything:

> **The profile builds a document’s citation tree purely from the nesting of
> `<tei:div>` elements inside `<tei:body>`.**

It does **not** read `<refsDecl>` / `<citeStructure>` from the `<teiHeader>`, and
it does **not** use XPath-based citation declarations. The relevant consequences:

- Every `<tei:div>` becomes a DTS `CitableUnit`.
- The depth of `<div>` nesting becomes the depth of the citation tree.
- The recursion descends **only** through `tei:div` — no other elements are
  treated as citable (see [Section 5](#5-limitations-and-gotchas)).
- The `citeType` is currently **hardcoded to `"Division"`** at every level.

### Identifiers

A citable unit’s reference string (its DTS `identifier`) is resolved as:

```
@xml:id  if present,  else  "exist:" || util:node-id($node)
```

The fallback (`util:node-id`) is an internal eXist node id that is **not stable** —
it can change when a document is re-indexed or edited. Reference resolution for the
Document and Navigation endpoints (`ref`, `start`, `end`) is done via
`doc/id($ref)`, i.e. it looks the value up as an `@xml:id`.

> **Rule:** Put an `@xml:id` on **every** `<div>` you want to be citable or
> navigable. The `@xml:id` values *are* your DTS citation identifiers. Make them
> meaningful and stable (e.g. `C1.E2`). They only need to be unique within the
> document.

### Titles

Each `CitableUnit`’s title is taken from the div’s `<tei:head>`, falling back to
`@n` if there is no `<head>`. The head is rendered through your ODD in `toc` mode.
A div with neither `<head>` nor `@n` produces a unit with no title.

---

## 2. Recommended document structure

A minimal but complete document that serves cleanly through all endpoints:

```xml
<?xml-model href="..." ?>
<TEI xmlns="http://www.tei-c.org/ns/1.0">
  <teiHeader>
    <fileDesc>
      <titleStmt>
        <title>Dracula</title>
        <author>Bram Stoker</author>
      </titleStmt>
      <!-- publicationStmt, sourceDesc ... -->
    </fileDesc>
    <profileDesc>
      <langUsage>
        <language ident="en">English</language>
      </langUsage>
    </profileDesc>
  </teiHeader>
  <text>
    <body>
      <div xml:id="C1">
        <head>Chapter 1: Jonathan Harker’s Journal</head>
        <div xml:id="C1.E1">
          <head>3 May. Bistritz</head>
          <p>...</p>
        </div>
        <div xml:id="C1.E2">
          <head>4 May</head>
          <p>...</p>
        </div>
      </div>
      <div xml:id="C2">
        <head>Chapter 2</head>
        ...
      </div>
    </body>
  </text>
</TEI>
```

### Why each part matters

| Element / attribute | Role in the DTS API |
|---|---|
| `<text>/<body>` | Required entry point. The citation tree is generated from `$doc//tei:body`. |
| `<div>` nesting | Defines the citation hierarchy. One `<div>` per citable level. |
| `@xml:id` on each `<div>` | Becomes the `CitableUnit` `identifier` / DTS reference string. Stable, meaningful, unique within the document. |
| `<head>` on each `<div>` | Becomes the unit’s `dublinCore.title` in Navigation responses (rendered via ODD `toc` mode). |
| `@n` (optional) | Fallback title when `<head>` is absent. |

### Encoding constraint

Use `<div>` for **every** citable level. Verse/line citation
(`<lg>`/`<l>`), paragraph-level citation (`<p>`/`<ab>`), and page/milestone-based
citation (`<pb/>`) are **not** turned into citable units by the current code. If
you need those levels, model them as nested `<div>`s or extend the profile.

This is a deliberate divergence from the spec’s flexibility: the DTS spec is
structure-agnostic, and the spec-aligned TEI approach would use `tei:citeStructure`
with `@match` XPath. The profile does not implement that path.

---

## 3. Header and metadata (Collection endpoint)

Resource-level metadata in Collection responses is pulled from TEI Publisher’s
**index fields**, not read live from the header at request time:

```
title     →  ft:field($doc, "title")
creator   →  ft:field($doc, "author")
date      →  ft:field($doc, "date")
language  →  ft:field($doc, "language")
```

These fields are populated by your app’s index configuration from the
`<teiHeader>` (in a standard `base` / `base10` app: title from
`titleStmt/title`, author from `titleStmt/author`, etc.).

**Practical requirements:**

- Give every document a proper `<teiHeader>` with at least `titleStmt/title` and
  `titleStmt/author`, plus `langUsage/language/@ident` for language.
- The document must be **indexed** by TEI Publisher. The resource lookup filters
  on `ft:query(., "file:*")`, so the file has to live in your indexed data
  collection and have been processed — not merely present on disk.
- Each document needs its TEI Publisher processing instruction / ODD association.
  The Document endpoint’s non-XML media types (HTML, EPUB, PDF, Markdown) and the
  `toc`-mode heading rendering both go through `tpu:parse-pi()` and your ODD’s
  transform.

---

## 4. Collection definitions (configuration, not TEI)

The collection hierarchy is **not** derived from your TEI or folder structure.
You declare it in `config.json` under `features.dts.member` (see [Configuration](#configuration) above).

---

## 5. Limitations and gotchas

- **`nav=parents`** on the Collection endpoint returns an incorrect member list.
- **Multiple citation trees** (the `tree` parameter) are defined in the spec but
  **not implemented**. Do not plan an encoding that depends on serving more than
  one citation tree for the same text (e.g. both page-based and chapter-based).
- **Navigation pagination** is not yet functional — relevant if any single `<div>`
  has a very large number of child `<div>`s.
- **Only `<div>` is citable.** Line-, paragraph-, and milestone-level citation are
  not supported without extending the profile.
- **Unstable ids without `@xml:id`.** Omitting `@xml:id` yields `exist:`-prefixed
  internal node ids that can change on re-indexing.

---

## 6. Encoding checklist

- [ ] Document has `<text>/<body>`.
- [ ] Every citable section is a `<tei:div>`; nesting reflects the desired
      citation depth.
- [ ] Every citable `<div>` has a stable, meaningful `@xml:id` (unique within the
      document).
- [ ] Every citable `<div>` has a `<head>` (or at least `@n`) for its title.
- [ ] `<teiHeader>` provides `titleStmt/title`, `titleStmt/author`, and
      `langUsage/language/@ident`.
- [ ] Document is placed under a configured collection `path` and indexed.
- [ ] Document has its TEI Publisher PI / ODD association for non-XML output and
      heading rendering.
- [ ] Collection(s) declared in `config.json` under `features.dts.member`.



