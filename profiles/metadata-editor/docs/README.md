# Feature for editing metadata

The feature allows for editing the contents of the `teiHeader` element as a separate page, or within
the jinntap editor.

## Stand-alone

The editor is available as a stand-alone version. It has its own page that can be opened by clicking
the `Edit metadata` button in the browse collection page. This is intended for big forms where there
are many separate fields that require visual space.

## In jinn-tap

The editor also integrates with jinn-tap: See `Edit metadata` button on the upper-right corner of the breadcrumbs area. This is intended for few fields where it makes
sense to edit them alongside the body of an edition.

## Customization

The profile comes with a basic example that edits the title of a document (first `title` element
within `titleStmt`, and the author(s) (any `author` element within `titleStmt`).  This is meant as
an example to be customized later on. The sample form shows you how to edit existing elements in the
`teiHeader` with two different behaviours: the example form expects that there is only one `title`
element and that is why only the first one can be edited; on the other hand, the form expects that
there is one or more authors.

The changes should be made in the `form.html` file, where
[Fore](https://jinntec.github.io/Fore/doc/index.html) is used to define a form for the
`teiHeader`. To add for example an input field for the `teiHeader/sourceDesc/bibl` element, include
something like the following to make the element editable.

```html
<fieldset>
  <label>Source Description</label>
  <fx-control ref="/TEI/teiHeader/sourceDesc/bibl"></fx-control>
</fieldset>
```


# Credits

Metadata editing, both stand-alone and directly from the JinnTap profile, was commissioned by [the
Office of the Historian](https://history.state.gov/), U.S. Department of State.
