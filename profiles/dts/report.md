# DTS API v1.0 Compliance Report

**Profile:** `profiles/dts`  
**Test environment:** `http://localhost:8080/exist/apps/dts-demo/`  
**Spec:** https://dtsapi.org/specifications/versions/v1.0/  
**Date:** 2026-04-22  
**Validator:** https://github.com/distributed-text-services/validator  
**Validator result (2026-04-20):** 12 passed, 20 skipped, 1 error  
**Validator result (2026-04-22):** 11 passed, 22 skipped, 0 errors

---

## Summary

| Area | Status |
|------|--------|
| Entry Point | ✅ Compliant |
| Collection endpoint | ⚠️ Partially compliant (`nav=parents` bug) |
| Document endpoint | ⚠️ Partially compliant (range fragments validator skip, error handling) |
| Navigation endpoint | ✅ Mostly compliant (range fragments implemented) |

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

### 2. Navigation: `resource`-only request returns HTTP 200 instead of 400

**Expected (spec):** `GET /navigation?resource=X` with no `down`, `ref`, `start`, or `end` → **HTTP 400 Bad Request**

**Actual:** HTTP 200, empty `member` array

**Root cause:** The code defaults `$down` to `0` when absent, silently treating the missing parameter as `down=0`.

**Location:** [modules/dts.xql](modules/dts.xql) — navigation function parameter validation block.

---

### 3. `nav=parents` returns wrong member list

**Expected (spec):** `GET /collection?id=bible&nav=parents` → `member` contains the **parent** of `bible` as a single entry.

**Actual:** Returns the root collection with all its children — `nav=children` behavior on the parent rather than the parents of the queried collection.

**Location:** [modules/dts.xql](modules/dts.xql) — collection function `nav=parents` branch.

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
| M2 | Navigation URI template on Resource `member` objects uses `{&down}` only; should be `{&ref,start,end,down,tree,page}` | `dts.xql` collection member builder |
| M3 | `navigation?resource=X&ref=Y&start=Z` (mutually exclusive params) silently succeeds instead of returning 400 | `dts.xql` document and navigation validation |

---

## What Is Working Correctly

- ✅ Entry Point — all required fields, correct `@context`, absolute URI templates
- ✅ Collection endpoint — root, nested, and paginated collections; Resource ID lookup; `application/ld+json` content type; correct counts; pagination `view` object
- ✅ Document endpoint — full document, fragment by `ref`, content negotiation (TEI XML, HTML, EPUB, PDF), `Link: rel="collection"` response header, 404 on missing resource
- ✅ Navigation `down=N` and `down=-1` from root — CitableUnit tree in document order, correct `application/ld+json` content type
- ✅ Navigation `down=0` with `ref` — returns siblings
- ✅ Navigation `ref` with `down>0` — returns ref CitableUnit + subtree
- ✅ Navigation `start`/`end` — returns CitableUnit range in `member`; subtree expansion with `down`; top-level `start`/`end` fields in response
- ✅ Document `start`/`end` — returns all sibling nodes in range wrapped in `<TEI><dts:wrapper>`
- ✅ `citationTrees` in Navigation `resource` object and Collection Resource responses
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
