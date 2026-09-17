# EDEp – EpiDoc Editor

This feature provides a form-based editor for [EpiDoc](https://epidoc.stoa.org/) inscriptions, together with person and place register editors and a Zotero-backed bibliography.

The editing UI is off by default. Enable it in your application's `config.json` (or in the front matter of an HTML template) when you want users to create and edit inscriptions.

## Configuration

```json
"features": {
    "edep": {
        "editor": {
            "enabled": false
        }
    },
    "zotero": {
        "api_base": "https://api.zotero.org",
        "group_id": "2519759",
        "style": "digital-humanities-im-deutschsprachigen-raum",
        "api_key": ""
    }
}
```

### `features.edep`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `editor.enabled` | boolean | `false` | When `true`, shows the actions to create and edit inscriptions, people and places, and to synchronize the Zotero bibliography. |

With the editor enabled, the following UI is added:

- a **New inscription** action on the document browse page
- an **Edit inscription** action on document listings and in the document view toolbar
- **New** actions on the people and places register pages
- a **Synchronize Bibliography** action on the browse page (restricted to logged-in users)

### `features.zotero`

These values are baked into the generated Zotero API module at application generation time. Change them in `config.json` and regenerate the app.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `api_base` | string | `https://api.zotero.org` | Base URL of the [Zotero Web API](https://www.zotero.org/support/dev/web_api/v3/start). Use the official API unless you proxy it. |
| `group_id` | string | `2519759` | Numeric ID of the Zotero group library to sync. Synced items are stored under `data/zotero/groups/{group_id}/`. |
| `style` | string | `digital-humanities-im-deutschsprachigen-raum` | Citation style identifier passed to the Zotero API as `style`. Any [CSL style](https://www.zotero.org/styles) known to Zotero can be used; it controls how bibliography entries are formatted in the editor. |
| `api_key` | string | `""` | Optional [Zotero API key](https://www.zotero.org/settings/keys). Required for private groups; may be left empty for public groups. Do not commit a real key to version control. |

Bibliography autocomplete in the form editor searches the locally synced cache, not Zotero live. After changing `group_id` or `style`, run **Synchronize Bibliography** so the cache matches the configured library.
