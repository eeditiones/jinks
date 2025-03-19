# Features for correspondence editions

This feature includes an additional toolbar to navigate between letters in a correspondence edition, in particular:

* open the next/previous letter in the sequence of letters defined by the edition
* navigate to the next/previous letter within the current correspondence

## Requirements

1. the TEI header **must** include a `correspDesc` element with two `correspAction` elements
    * `<correspAction type="sent">`
    * `<correspAction type="received">`
2. the `correspDesc` **must** also specify a `correspContext` with references to the next/previous letter in sequence