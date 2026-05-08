---
name: test-blueprint
description: >-
  Generate an app from one of the Jinks/TEI Publisher blueprints and run its test suite.
---

Config files for testable apps are located in `demo/*.json`.

## Steps

Given a config file (e.g. `demo/ser_config.json`), determine the app abbreviation from `pkg.abbrev` in that JSON file (e.g. `tp-serafin`). Then:

1. **Remove old application:**
   ```
   xst package remove <abbrev>
   ```

2. **Create the app on the server:**
   ```
   jinks create -c <config>
   ```

3. **Download the app as a xar archive:**
   ```
   jinks run <abbrev> download -o <tempdir>
   ```
   This saves `<abbrev>.xar` into `<tempdir>` (for example `/tmp/<abbrev>.xar` when `-o /tmp` is used).

4. **Unpack the xar into a temporary directory:**
   ```
   TMPDIR=$(mktemp -d /tmp/<abbrev>-XXXXXX)
   unzip -q <tempdir>/<abbrev>.xar -d "$TMPDIR"
   ```

5. **Install dependencies and run tests:**
   ```
   cd "$TMPDIR"
   npm install
   npx cypress run --browser chrome
   ```

6. Report the Cypress test results (passing, failing, pending, skipped counts).

## Recommended one-shot execution

For reproducibility, prefer a single command chain from the repository root:

```bash
ABBREV=<abbrev> && CONFIG=<config-path> && xst package remove "$ABBREV" && jinks create -c "$CONFIG" && jinks run "$ABBREV" download -o /tmp && TMPDIR=$(mktemp -d "/tmp/${ABBREV}-chrome-full-XXXXXX") && unzip -q "/tmp/${ABBREV}.xar" -d "$TMPDIR" && cd "$TMPDIR" && npm install && npx cypress run --browser chrome
```

## Notes

- The server (eXist-db) must be running at `http://localhost:8080` before running these steps.
- The downloaded xar is left in the directory passed via `-o` (commonly `/tmp`); the unpacked temp directory is left in `/tmp`.
- Tests use Cypress and target the live app on the server, so the app must remain deployed during the test run.
- Use `--browser chrome` for consistency with current project expectations.

## Troubleshooting

- **If server is not reachable, then verify and retry**:
  ```bash
  curl -I http://localhost:8080/exist/ || echo "eXist-db is not reachable"
  ```
  If unreachable, start/restart eXist-db, then rerun the one-shot command chain.

- **If uninstall fails because app is missing, then continue**:
  ```bash
  xst package remove <abbrev> || true
  ```
  Missing app is acceptable; proceed to `jinks create -c <config>`.

- **If archive is not found, then validate the output directory**:
  ```bash
  jinks run <abbrev> download -o /tmp && ls -l /tmp/<abbrev>.xar
  ```
  Always unzip from the explicit output path: `/tmp/<abbrev>.xar` (or your chosen `-o` directory).

- **If Chrome is not detected by Cypress, then inspect browser discovery**:
  ```bash
  npx cypress info
  ```
  Confirm Chrome appears in detected browsers before rerunning `npx cypress run --browser chrome`.

- **If run is flaky or interrupted, then force a clean rerun**:
  ```bash
  ABBREV=<abbrev> && CONFIG=<config-path> && xst package remove "$ABBREV" || true && jinks create -c "$CONFIG" && jinks run "$ABBREV" download -o /tmp && TMPDIR=$(mktemp -d "/tmp/${ABBREV}-chrome-full-XXXXXX") && unzip -q "/tmp/${ABBREV}.xar" -d "$TMPDIR" && cd "$TMPDIR" && npm install && npx cypress run --browser chrome
  ```
