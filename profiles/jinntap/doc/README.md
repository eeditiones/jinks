The **Jinntap** integration brings editing of your documents directly in your app. It enables
creating new TEI (and JATS) files and editing existing ones. Read more about JinnTap, get help on editing or learn about customization in its [documentation](https://jinnelements.github.io/jinn-tap/).

# Customising the editor

JinnTap is configured through a JSON schema (`tei-schema.json` / `jats-schema.json`): which
elements exist, their attributes, toolbar buttons, shortcuts, and optional authority
connectors. Styling uses ordinary CSS against the prefixed custom elements in the editor
(`tei-rs`, `jats-sec`, …).

**How to add an element, style it, put it on the toolbar, and wire a connector** is documented
in the JinnTap library docs:

→ [Customizing the editor](https://jinnelements.github.io/jinn-tap/guide/customizing/)

In a TEI Publisher app the schema and stylesheet paths are set under `features.jinntap`
(see below). Edit the copies under `resources/schema/` and `resources/css/` in your
generated application.

# Configuration

The jinntap feature can be configured like this:

```jsonc
"features": {
  "jinntap": {
    "version": "<version>",
    "cdn": "https://cdn.jsdelivr.net/npm/@jinntec/jinntap",
    "default-format": "tei",
    "formats": {
      "tei": {
        "schema": "resources/schema/tei-schema.json",
        "stylesheet": "editor-styles.css"
      },
      "jats": {
        "schema": "resources/schema/jats-schema.json",
        "stylesheet": "jats-editor-styles.css"
      }
    }
  }
}
```

The schema defines the toolbar, which elements can be edited, and more. Full schema
reference: [https://jinnelements.github.io/jinn-tap/schema/](https://jinnelements.github.io/jinn-tap/schema/).

## Collaboration

Jinntap enables collaboration of multiple authors in the same document.

```jsonc
"features": {
  "collab": {
    "enable": true,
    "server": "wss://dev.tei-publisher.com/collab"
  }
}
```

## Integration with IIIF profile

The jinntap feature integrates with the IIIF profile to show the facsimile of the document you're
working on. It requires the IIIF profile to be enabled, and the viewer to be pb-facsimile.

```json
"features": {
    "iiif": {
        "viewer": "pb-facsimile",
        "base_uri": "https://apps.existsolutions.com/cantaloupe/iiif/2/",
        "enabled": true
    }
}
```

If the documents are referencing images, the configuration needs to set its `"type"` to `"image"`:

```json
"features": {
    "iiif": {
        "viewer": "pb-facsimile",
        "base_uri": "https://apps.existsolutions.com/cantaloupe/iiif/2/",
        "enabled": true,
        "type": "image"
    }
}
```

### Assumptions

The same conditions for IIIF manifest generation are assumed here. Refer to the IIIF profile to see
how it is set up.

The textual content of the transcription should always be preceded by a `<pb />` element to point to
the facsimile of the first page.

The Cortez example in the demo content profile is set up in a way that will work with the jinntap
profile. To see it, create a new application with the demo data profile, the jinntap profile and the
IIIF profile. Set the `features.iiif.viewer` option to `pb-facsimile` and open the `CIDTC-3823-cortez.xml` demo document.

## Credits

Integrating facsimiles with the JinnTap profile is commissioned by [the Office of the Historian](https://history.state.gov/), U.S. Department of State.
