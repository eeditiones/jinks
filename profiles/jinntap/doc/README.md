The **Jinntap** integration brings editing to your documents directly in your app. It enabled creating new TEI files and editing existing ones.

## Configuration

The jinntap feature can be configured like this:

```json
"features": {
 "jinntap": {
    "version": "<version>",
    "cdn": "https://cdn.jsdelivr.net/npm/@jinntec/jinntap",
    "schema": "resources/schema/schema.json"
  }
}
```

The schema defines the toolbar, which elements can be edited and more.

## Collaboration

Jinntap enables collaboration of multiple authors in the same document.

```json
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
IIIF profile. Set the `features.iiif.viewer` option to `pb-facsimile` and open the the
`CIDTC-3823-cortez.xml` demo document.
