# Distributed Text Services (DTS)

This profile adds a standards-compliant [DTS 1.0 API](https://distributed-text-services.github.io/specifications/) to your TEI Publisher application, enabling external clients to discover, navigate, and retrieve documents using a well-defined REST interface. It also provides a built-in DTS browser page for interactively exploring any DTS-compatible server from within your application.

The profile requires additional configuration in order to provide a meaningful service (see below). For demonstration purposes, the _DTS Blueprint_ is provided, which includes auxiliary data and an ODD to demonstrate how to use DTS to embed passages from external resources (the bible in this case).

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

Fragment selection is supported via the `ref` parameter (by citable node identifier).

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

- **Range fragments** (`start`/`end` on the Document endpoint): accepted but only the start node is returned; full range extraction is not yet implemented.
- **`nav=parents`** on the Collection endpoint returns an incorrect member list.
- **Navigation range queries** (`start`/`end` on the Navigation endpoint) are not implemented.
- **Multiple citation trees** (the `tree` parameter) are defined in the spec but not implemented.
- **Navigation pagination** is not yet functional.
