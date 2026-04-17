# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is jinks

Jinks is an **application manager for TEI Publisher**, running as an eXist-db XQuery application. It generates, configures, and updates custom TEI Publisher applications via a *profile* system. It is not a Node.js or browser app — the runtime is eXist-db (an XML database), and all application logic is XQuery.

The npm/esbuild toolchain exists only to bundle frontend assets (Monaco editor workers, SASS for the jinks UI itself and the `theme-base10` profile).

## Build & Deploy

```bash
# Install/update frontend dependencies and compile assets
npm install
npm run build       # esbuild + SASS via build.cjs

# Package as an eXist .xar file (requires Apache Ant)
ant                 # runs clean → vendor → xar targets

# One-shot: build + package + install into local eXist (port 8080)
./build.sh          # npm run build && ant && xst package install --force build/jinks.xar
```

The built xar is placed in `build/jinks.xar`. `xst` ([@existdb/xst](https://github.com/eXist-db/xst)) is the CLI used for deployment.

Live development sync to a running eXist instance is configured in `.existdb.json` — use the [existdb VSCode extension](https://github.com/eXist-db/existdb-vscode) to watch and push changes automatically.

## Tests

Tests are Cypress e2e tests that require jinks to be installed and running in eXist at `http://localhost:8080/exist/apps/jinks`.

```bash
npm test                        # npx cypress run (headless)
npx cypress open                # interactive Cypress UI
npx cypress run --spec "test/cypress/e2e/api.cy.js"   # single spec
```

Test specs live in `test/cypress/e2e/`. The `cypress.config.cjs` points to that directory.

## Architecture

### Profiles (`profiles/`)

The central concept. Every profile is a directory under `profiles/` and must contain `config.json`. Three kinds:

- **blueprint** — complete app template for a use case (monograph, correspondence, etc.)
- **feature** — adds specific functionality (docker, registers, annotations, etc.)
- **theme** — visual customization only

A profile's `config.json` may specify `"extends"` (array of profile names) to inherit and merge configurations. The base profile for all TEI Publisher 10 apps is `profiles/base10/`.

If a profile needs custom generation logic it includes `setup.xql`, which may declare functions annotated with `%generator:prepare`, `%generator:write`, and `%generator:after-write`. Without `setup.xql` (or without a `%generator:write` function), jinks defaults to `cpy:copy-collection($context)` — copying all files from the profile into the target.

Files with `.tpl` in the name are treated as templates and expanded via the [jinks-templates](https://github.com/eeditiones/jinks-templates) module using the merged configuration map.

### XQuery modules (`modules/`)

| Module | Purpose |
|--------|---------|
| `generator.xql` | Main entry point: `generator:process($settings, $config)` — orchestrates prepare → write → after-write |
| `cpy.xql` | File copy/write helpers; SHA-256 hash tracking for conflict detection (stored in `.jinks.json` in the target app) |
| `api.xql` | REST API handlers (served via [Roaster](https://github.com/eeditiones/roaster)) |
| `deploy-api.xql` | Deployment-related API endpoints |
| `config.xql` | App-level config constants (`$config:app-root`, etc.) |
| `paths.xql` | Path resolution utilities |
| `actions.xql` | Named actions (reindex, fix-odds, download, file-sync) |
| `template-utils.xql` | Template helper utilities |

### Conflict handling

On update, jinks compares SHA-256 hashes stored in `.jinks.json` inside the target app. Files the user has modified since last install are reported as conflicts and not overwritten (unless `overwrite=reinstall`).

### Frontend assets

`npm run build` (via `build.cjs`) does three things:
1. Bundles Monaco editor workers → `resources/scripts/dist/`
2. Compiles `resources/styles/pico-jinks.sass` → `resources/styles/pico-jinks.css`
3. Compiles `profiles/theme-base10/resources/sass/pico-components.sass` → `profiles/theme-base10/resources/css/pico-components.css`

The `ant vendor` target copies pre-built assets from `node_modules/@teipublisher/pb-components` and `@teipublisher/jinks-file-manager` into `resources/lib/`, `resources/css/`, etc.

### API

The OpenAPI spec is at `schema/openapi-3.0.json`. The web UI is served at `http://localhost:8080/exist/apps/jinks` and the API explorer at `/api.html`.

### Profile config schema

All `config.json` files reference `schema/jinks.json` via `"$schema": "../../schema/jinks.json"`.
