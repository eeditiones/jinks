## Timeline Components

### Requirements

For the timeline component to work, a field and a facet, both called `date`, need to be defined on each document in `collection.xconf`:

1. the field should provide a single date per document with type `xs:date`
2. the facet indexes the three components of the date, i.e. year, month and day in a hierarchical fashion

By default, both are injected into `collection.xconf` as given in `templates/timeline-blocks.html`:

```xml
<field name="date" expression="nav:get-metadata(ancestor::tei:TEI, 'date')"/>
<facet dimension="date" expression="nav:get-metadata(ancestor::tei:TEI, 'date') => tokenize('-')" hierarchical="yes"/>
```

### Configuration

```json
"features": {
    "timeline": {
        "enabled": true,
        "document-view": false
    }
}
```

* `enabled`: enables the timeline when browsing documents.
* `document-view`: show timeline also in single document view. Only works for correspondence and expects a `<correspContext>` containing pointers to the next and/or previous letter.