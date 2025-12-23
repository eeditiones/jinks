## Entity registers

This feature handles entity registers, i.e. lists of people, places and other entity types associated with the documents in the edition.

### Features

1. provides an additional sidebar for the document view, showing all entities appearing in the currently visible text. For places this includes a map view.
2. adds separate pages to browse people, places, and bibliography

### Configuration

To enable the sidebar, set the feature `register` to `true` in the configuration:

```json
"features": {
    "register": {
        "enabled": true
    }
}
```

You can do this either globally for all pages in the corresponding top `features` property of `config.json`, or by collection as a subproperty within `collection-config`.

To switch it off in a particular template, set the `enabled` property to `false` in the template front matter:

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

#### Encoding

The default configuration and scripts assume that the register entries are organized as lists of `<person>` and `<place>` elements, and that the mentions in the documents are encoded as `<personName>` and `<placeName>` respectively, with a `@key` attribute containing the `@xml:id` of the given entity. If your encoding is slightly different (e.g. use of `<rs>` for encoding the references) you can adapt the file `modules/registers-api.xql` accordingly.


#### Index configuration

This features requires a specific index configuration (see `collection.xconf`) to be available for `person` and `place` entries in the registers.
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

#### ODD

The TEI Publisher ODD (`resources/odd/teipublisher.odd`) contains several models to process the most common elements used to encode entities. For the generation of the individual register entry page, the processing scenario is set with the `register-details` mode (see models with the `@predicate` `$parameters?mode='register-details'`). The list of entities that appear in a document or fragment being displayed is processed under the `register` mode.

### Layout

#### Browse pages for registers

To control the number of columns in browse pages, set the css variable ` --pb-categorized-list-columns` in `resources/css/registers-theme.css`. By default it uses a two-column layout.

#### Sidebar

By default, registers appear in a sidebar to the right. This behaviour is set in `templates/register-blocks.html`:
```html
<template>
    [% template after %]
...
</template>
```

## Credits

This feature has been primarily funded by the [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](../../../resources/images/dhlab.svg)
