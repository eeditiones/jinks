# Features for correspondence editions

This feature includes an additional toolbar to navigate between letters in a correspondence edition, in particular:

* open the next/previous letter in the sequence of letters defined by the edition
* navigate to the next/previous letter within the current correspondence

## Requirements

1. the TEI header **must** include a `correspDesc` element with two `correspAction` elements
    * `<correspAction type="sent">`
    * `<correspAction type="received">`
2. the `correspDesc` **must** also specify a `correspContext` with references to the next/previous letter in sequence

Appropriate processing model rules for `correspDesc` are already contained in `teipublisher.odd`.

## Configuration

The feature adds a single boolean property to the *extensions* section of the config:

```json
{
    "features": {
        "correspondence": {
            "navigation": false
        }
    }
}
```

To enable correspondence navigation in your app, set `"navigation": true` either in your `config.json` or the frontmatter of an HTML template.

## Examples

See the ~Serafin Correspondence~ blueprint for an example.