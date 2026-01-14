# Features for toggles in the toolbar

This feature includes a toggle section to control some aspects of the presentation of the edition text, such as:

* source or edited text (e.g. faithful transcription of the source vs normalized by the editor)
* optional display of the columns and lines of the source
* interactive elements vs undisturbed reading view

## Requirements

Appropriate processing model rules are largely already contained in `teipublisher.odd`.

## Configuration

* toggle blocks can be individually switched on/off from the `config.json`

```json
{
    "features": {
        "toolbar-toggles": {
            "enabled": true,
            "toggle-reading": true,
            "toggle-normalized": false
        }
    }
}
```

To enable toggle options in your app, set `toolbar-toggles/enabled` to `true` together with selected toggle switch either in your `config.json` or the frontmatter of an HTML template, as in the example above. 

## Credits

This feature has been primarily funded via [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](../../../resources/images/dhlab.svg)