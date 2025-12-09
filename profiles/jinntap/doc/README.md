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

It makes some assumptions on the XML format. The beginnings of pages should be encoded as `<pb n="1"
xml:id="my-id" facs="my-facsimile" />` with the `@facs` attribute in `pb` pointing to the manifest
of that facsimile.

The textual content of the transcription should always be preceded by a `<pb />` element to point to
the facsimile of the first page.

```xml
<TEI xmlns="http://www.tei-c.org/ns/1.0">
  <teiHeader>
    <fileDesc>
      <titleStmt><title>An example of facsimile in jinn-tap</title></titleStmt>
    </fileDesc>
  </teiHeader>
  <text>
    <body>
      <div>
        <pb n="79" xml:id="p1" facs="15929_000_IDL5772_BOss12034_IIIp79.jpg" />
        <p>Contents of the first page of the facsimile</p>
        <pb n="80" xml:id="p2" facs="15929_000_IDL5772_BOss12034_IIIp80.jpg" />
        <p>Contents of the second page of the facsimile</p>
      </div>
    </body>
  </text>
</TEI>
```
