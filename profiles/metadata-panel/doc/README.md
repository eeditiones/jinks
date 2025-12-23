# Feature for metadata section in the sidebar

This feature adds a basic metadata display block as a sidebar in the document view.

It processes the metadata from the `teiHeader` section of the source document, according to the ODD rules, customized for the `mode` parameter set to `metadata-panel`.

## Requirements

Appropriate processing model rules are largely already contained in `teipublisher.odd`.

## Configuration

To switch this feature off in a particular template, set the `enabled` property to `false` in the template front matter as follows:

```
<template>
    ---json
    {
        "templating": {
            "extends": "templates/pages/basic.html"
        },
        ...
        "features": {
            "metadata" : {
                "enabled" : false
            }
        }
    }
    ---
</template>
```

Any adjustments concerning the contents must be made in the ODD (see models with the `@predicate` `$parameters?mode='metadata-panel'`).

## Layout

By default, the metadata panel appears in a sidebar to the right. This behaviour is set in `templates/metadata-blocks.html`:
```html
<template>
    [% template after %]
...
</template>
```

## Credits

This feature has been primarily funded by the [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](../../../resources/images/dhlab.svg)