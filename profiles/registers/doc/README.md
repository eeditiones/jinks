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

#### Browse pages for registers

To control the number of columns in browse pages, set the css variable ` --pb-categorized-list-columns` in `resources/css/registers-theme.css`. By default it uses two-column layout.
