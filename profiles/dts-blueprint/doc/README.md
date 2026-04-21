# DTS Blueprint

A blueprint demonstrating the [DTS profile](../../dts) using 3 of Karl Barth's *Predigten 1915* as primary text alongside the Luther Bible.

The blueprint also shows a practical use case for DTS: embedding passages from an external DTS resource (the Luther Bible) directly into a local edition. The included `barth.odd` demonstrates how to resolve DTS references and render quoted bible passages inline.

## Included data

| Collection id | Content |
|---------------|---------|
| `barth` | Karl Barth: *Predigten 1915* (default data collection) |
| `bible` | Luther Bible — a TEI-encoded bible used as an external DTS source |

## External servers

The blueprint pre-configures the Heidelberg University DTS service in the browser dropdown:

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

This illustrates how any external DTS server can be made available to users of your application.
