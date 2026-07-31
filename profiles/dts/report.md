# DTS API v1.0 Compliance Report

**Profile:** `profiles/dts`  
**Test environment:** `http://localhost:8080/exist/apps/dts-demo/`  
**Spec:** https://dtsapi.org/specifications/versions/v1.0/  
**Date:** 2026-07-31  
**Validator:** https://github.com/distributed-text-services/validator  
**Validator result (2026-04-20):** 12 passed, 20 skipped, 1 error  
**Validator result (2026-04-22):** 11 passed, 22 skipped, 0 errors  
**Validator result (2026-07-31):** 12 passed, 21 skipped, 0 errors  
**Validator result (2026-07-31, after #3):** 10 passed, 20 skipped, 3 failed (navigation: `down=1` too deep + duplicate `xml:id` lookup)  
**Validator result (2026-07-31, after nav fixes):** 13 passed, 20 skipped, 0 errors  

---

## Summary

| Area | Status |
|------|--------|
| Entry Point | ✅ Compliant |
| Collection endpoint | ✅ Compliant (`nav=parents` fixed) |
| Document endpoint | ⚠️ Partially compliant (range fragments validator skip, error handling) |
| Navigation endpoint | ✅ Mostly compliant (resource-only 400; range fragments) |

---

## Fixed in this session

The following issues were identified and fixed while running the validator:

| # | Issue | Fix |
|---|-------|-----|
| F1 | Entry Point and all endpoints returned **relative URLs** — validator and clients couldn't follow links | Added `dts:server-base()` to prepend `scheme://host:port` to all generated URIs |
| F2 | Navigation endpoint returned **`Content-Type: application/xml`** instead of `application/ld+json` | Wrapped navigation return value in `router:response(200, "application/ld+json", ...)` |
| F3 | Navigation `member` serialized as **object instead of array** when only one item present | Wrapped `dts:navigation-tree()` result in `array { }` to force JSON array serialization |
| F4 | `dublinCore: null` in collection responses **failed schema validation** | Conditionally include `dublinCore` only when the value exists |
| F5 | `citeStructure` contained **`[null]` for leaf nodes** and **nested arrays** for children | Fixed `dts:cite-structure()` to omit `citeStructure` key on leaf nodes and use `array { }` for recursion |
| F6 | Collection endpoint returned **404 for Resource IDs** (e.g. `?id=bible/luther-bibel.xml`) | Added Resource ID handling: parse `collectionId/resourceId`, look up the document, return full Resource response |
| F7 | Navigation `resource`-only (and `down=0` without `ref`) returned **HTTP 200** instead of **400** | Reject when `resource` is present but neither a non-zero `down`, nor `ref`, nor `start`/`end` is provided; treat empty-string Roaster params as absent; use `error($errors:BAD_REQUEST)` |
| F8 | Collection Resource `navigation` URI template was **`{&down}` only**, so validator `start`/`end` expansions were dropped | Expanded template to `{&ref,start,end,down,tree,page}` |
| F9 | Collection `nav=parents` returned the **parent’s children** instead of the parent | Keep queried `@id`; put parent Collection(s) in `member` via `dts:as-collection-member()` |
| F10 | Navigation `down=1` included **level-2** units (tree started at level 0) | Start `dts:navigation-tree` at level 1 so `down=N` means N levels from the root |
| F11 | `ref` / `start` / `end` lookup failed on **duplicate `xml:id`** values (`id()` sequence failed `instance of element()`) | `dts:resolve-ref-node()` uses `head(id($ref, $doc))`; missing start/end → 404 |

---

## Remaining Issues

### 1. Range fragments (`start` + `end`) — ✅ Implemented (2026-04-22)

**Validator test:** `test_navigation_range_response_validity` — **PASSED**; `test_document_range_response_validity` — **SKIPPED** (validator picks `odd/osinski.odd` which has no `tei:div` citable units — a test-infrastructure issue, not a code defect)

**What was fixed:**

- `dts:resolve-fragment()` now returns all sibling nodes from `$start` through `$end` inclusive (using `following-sibling::*[not(. >> $end-node)]`), wrapped in `<TEI><dts:wrapper>` in the XML response.
- `dts:navigation()` now routes `start`/`end` requests to the new `dts:navigation-range()` helper, which returns a `member` array of CitableUnits covering the range, with optional subtree expansion when `down > 1` or `down = -1`.
- Navigation responses with `start`/`end` include top-level `start` and `end` CitableUnit fields.
- The `@id` of Navigation responses now includes `ref`, `start`, and `end` parameters when present.

The spec's valid `start`/`end` combinations for Navigation are all handled:

| down | start/end | Behaviour |
|------|-----------|-----------|
| absent (defaults 0) | present | `member` = range CitableUnits, no subtree |
| > 0 | present | `member` = range CitableUnits + subtree to depth N |
| -1 | present | `member` = range CitableUnits + full subtree |

---

### 2. Navigation: `resource`-only request returns HTTP 200 instead of 400 — ✅ Fixed (2026-07-31)

**Validator:** no dedicated test; covered by manual check and by enabling correct `start`/`end` expansion (see F8). Suite result after fix: **12 passed, 21 skipped, 0 errors**.

**Expected (spec):** `GET /navigation?resource=X` with no `down`, `ref`, `start`, or `end` → **HTTP 400 Bad Request**. Same for `down=0` without `ref` (and for `down=0` with `start`/`end`).

**Previously:** HTTP 200, empty `member` array — `$down` defaulted to `0` when absent.

**Fix:** In `dts:navigation()`, normalize absent/empty Roaster params, then return `error($errors:BAD_REQUEST, …)` when:

| down | ref | start/end | Result |
|------|-----|-----------|--------|
| absent | absent | absent | 400 |
| 0 | absent | absent | 400 |
| 0 | absent | present | 400 |

Also pass `root($text)` into ref helpers (they require `document-node()`), which fixed `ref` lookups that previously raised `XPTY0004`.

**Location:** [modules/dts.xql](modules/dts.xql) — `dts:navigation()`.

---

### 3. `nav=parents` returns wrong member list — ✅ Fixed (2026-07-31)

**Expected (spec):** `GET /collection?id=bible&nav=parents` → response `@id` is `bible`, and `member` contains the **parent** of `bible` (here `default`) as a single entry.

**Previously:** Resolved the parent as `$collectionInfo`, then listed that parent’s children — i.e. `nav=children` on the parent (`@id` was `default`, `member` was bible/barth/odd).

**Fix:** Always resolve the queried collection for the response body. When `nav=parents`, build `member` from the parent Collection(s) via `dts:as-collection-member()`; keep `totalChildren` as the queried item’s real child count. Resource IDs with `nav=parents` likewise return the parent collection in `member`.

**Verified:**

| Request | `@id` | `member` |
|---------|-------|----------|
| `?id=bible&nav=parents` | `bible` | `[default]` |
| `?id=bible` | `bible` | resources (unchanged) |
| `?id=bible/luther-bibel.xml&nav=parents` | resource | `[bible]` |
| `?nav=parents` (root) | `default` | `[]` |

**Location:** [modules/dts.xql](modules/dts.xql) — `dts:collection()`, `dts:as-collection-member()`.

---

### 4. Navigation `@id` field is incomplete

Per spec, the `@id` of a Navigation response must be the full self-referential request URI. The current build includes only `resource` and `down`, omitting `ref`, `start`, `end`, and `tree`.

---

### 5. Multiple Citation Trees (`tree` parameter) not implemented

The `tree` query parameter appears in URI templates and the OpenAPI spec but has no handling logic. Resources with multiple citation schemes cannot select between them.

---

### 6. Navigation pagination not implemented

The `page` parameter is declared but not functional on the navigation endpoint.

---

## Minor / Conformance Issues

| # | Issue | Location |
|---|-------|----------|
| M1 | 400 error body for missing `resource` param is raw Roaster framework JSON (verbose, exposes internal paths) | Roaster parameter validation |
| M2 | ~~Navigation URI template on Resource `member` objects uses `{&down}` only~~ — **fixed** (F8): now `{&ref,start,end,down,tree,page}` | `dts.xql` collection member builder |
| M3 | `navigation?resource=X&ref=Y&start=Z` (mutually exclusive params) silently succeeds instead of returning 400 | `dts.xql` document and navigation validation |

---

## What Is Working Correctly

- ✅ Entry Point — all required fields, correct `@context`, absolute URI templates
- ✅ Collection endpoint — root, nested, and paginated collections; Resource ID lookup; `nav=parents` (parent in `member`); `application/ld+json` content type; correct counts; pagination `view` object
- ✅ Document endpoint — full document, fragment by `ref`, content negotiation (TEI XML, HTML, EPUB, PDF), `Link: rel="collection"` response header, 404 on missing resource
- ✅ Navigation `down=N` and `down=-1` from root — CitableUnit tree in document order to the requested depth; correct `application/ld+json` content type
- ✅ Navigation `resource`-only / `down=0` without `ref` — HTTP 400 Bad Request
- ✅ Navigation `down=0` with `ref` — returns siblings
- ✅ Navigation `ref` with `down>0` / `down=-1` — returns ref CitableUnit + subtree
- ✅ Navigation `ref` without `down` — returns ref CitableUnit (empty `member`)
- ✅ Navigation `start`/`end` — returns CitableUnit range in `member`; subtree expansion with `down`; top-level `start`/`end` fields in response
- ✅ Document `start`/`end` — returns all sibling nodes in range wrapped in `<TEI><dts:wrapper>`
- ✅ `citationTrees` in Navigation `resource` object and Collection Resource responses
- ✅ Collection Resource `navigation` URI template includes `ref`, `start`, `end`, `down`, `tree`, `page`
- ✅ Collection `nav=parents` — queried `@id` with parent Collection(s) in `member`
- ✅ `dtsVersion: "1.0"` and DTS JSON-LD `@context` URL on all responses

---

## Running the Validator

```bash
# Install (one-time)
python3 -m venv /tmp/dts-validator-env
/tmp/dts-validator-env/bin/pip install https://github.com/distributed-text-services/validator/archive/refs/heads/main.zip
git clone --depth=1 https://github.com/distributed-text-services/validator /tmp/dts-validator-repo

# Run
cd /tmp/dts-validator-repo
/tmp/dts-validator-env/bin/python -m pytest tests/ \
  --entry-endpoint=http://localhost:8080/exist/apps/dts-demo/api/dts \
  --html=profiles/dts/validation-report.html \
  --self-contained-html -v
```
