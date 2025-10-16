## Entity registers

This feature handles entity registers, i.e. lists of people, places etc. associated with the documents in the edition.

### Features

1. provides an additional sidebar for the document view, showing all entities appearing in the currently visible text. For places this includes a map view.
2. adds separate pages to browse people and places

### Configuration

To enable the sidebar, set feature "register" to true in the config:

```json
"features": {
    "register": {
        "enabled": true
    }
}
```

You can do this in either globally for all pages in the corresponding top `features` property of `config.json`, or by collection as a subproperty within `collection-config`.

To switch it off in a particular template, set `enabled` property to `false` in the template front matter:

```
<template>
    ---json
    {
        "templating": {
            "extends": "templates/pages/basic.html"
        },
        ...
        "features": {
            "register" : {
                "enabled" : false
            }
        }
    }
    ---
</template>
```

### Requirements

This features requires a specific index configuration to be available for `person` and `place` entries in the registers.
Standard configuration is as follows:

```xml
<text qname="tei:place">
    <field name="name" expression="tei:placeName"/>
    <field name="sort-name" expression="head((tei:placeName[@type='sort'], tei:placeName)) =&gt; normalize-unicode('NFD')     =&gt; replace('\p{IsCombiningDiacriticalMarks}', '')"/>
</text>
<text qname="tei:person">
    <field name="name" expression="tei:persName"/>
    <field name="sort-name" expression="head((tei:persName[@type='sort'], tei:persName))=&gt; normalize-unicode('NFD')     =&gt; replace('\p{IsCombiningDiacriticalMarks}', '')"/>
</text>
```

Two fields must be defined in the index configuration, as above:

* `name`: by default uses all available name variants for a given entry; this field is used when querying the list of entries via the search field
* `sort-name`: by default uses just one name (the one with the `type='sort'`, if present, or the first available name otherwise) to group entries into groups by starting letter; diacritics are stripped for this purpose, therefore entries starting with `ś` and `s`, or `u` and `ü` will be grouped together

#### Browse pages for registers

To control the number of columns in browse pages, set the css variable ` --pb-categorized-list-columns` in `resources/css/registers-theme.css`. By default it uses two-column layout.

## Credits

This feature has been primarily funded via [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](../../../resources/images/dhlab.svg)
