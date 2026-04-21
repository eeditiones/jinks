# DTS API v1.0 Compliance Report

**Profile:** `profiles/dts`  
**Test environment:** `http://localhost:8080/exist/apps/dts-demo/`  
**Spec:** https://dtsapi.org/specifications/versions/v1.0/  
**Date:** 2026-04-20  
**Validator:** https://github.com/distributed-text-services/validator  
**Validator result (2026-04-20):** 12 passed, 20 skipped, 1 error

---

## Summary

| Area | Status |
|------|--------|
| Entry Point | ✅ Compliant |
| Collection endpoint | ⚠️ Partially compliant (`nav=parents` bug) |
| Document endpoint | ⚠️ Partially compliant (range fragments, error handling) |
| Navigation endpoint | ⚠️ Mostly compliant (range fragments missing) |

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

### 1. Range fragments (`start` + `end`) not implemented

**Validator test:** `test_document_range_response_validity` — **1 ERROR** (setup fails because navigation returns no `start`/`end` CitableUnits)

**Document endpoint:** `dts:resolve-fragment()` accepts `start`/`end` but returns only the start node.

**Navigation endpoint:** The `down` + `start`/`end` combinations are not implemented.

The spec defines these valid `start`/`end` combinations for Navigation:

| down | start/end | Expected result |
|------|-----------|-----------------|
| absent | present | Return start/end CitableUnits, no member array |
| > 0 | present | Subtree of range to depth N |
| -1 | present | Full subtree of range |

**Location:** [modules/dts.xql](modules/dts.xql) — `dts:resolve-fragment()` and navigation function.

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
