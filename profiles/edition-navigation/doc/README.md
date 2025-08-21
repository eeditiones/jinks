# Features for navigation in edition

This feature includes an additional toolbar to navigate between documents in edition, in particular:

* open the next/previous document in the sequence defined by the edition
* navigate to the next/previous letter within the current correspondence exchange (letters between a specific pair of correspondents)

## Requirements

1. the TEI header **must** include a `correspDesc` element 
2. the `correspDesc` **must** specify a `correspContext` with references to the next/previous document in sequence encoded with `ref` element with `@type` and `@target`; `@type` is expected to take either `previous` or `next` values
3. the `correspContext` **may** specify additional `ref`s with `@type` set to either `previous-in-correspondence` or `next-in-correspondence`

Appropriate processing model rules for `correspDesc` are already contained in `teipublisher.odd`.

This navigation mechanism can be easily extended to edition-specific requirements by providing further `ref` with arbitrary types and extending the ODD to handle their specific meaning.

## Configuration

The feature adds a boolean property to the *extensions* section of the config:

```json
{
    "features": {
        "edition-navigation": {
            "navigation": false,
            "in-correspondence": false
        }
    }
}
```

To enable in-edition navigation in your app, set `"navigation": true` either in your `config.json` or the frontmatter of an HTML template. To enable additional navigation in correspondence exchange between each pair of correspondents, set `"in-correspondence": true` in addition.

## Examples

See the ~Serafin Correspondence~ blueprint for an example.