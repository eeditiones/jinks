# Feature for editing metadata

The feature allows for editing the contents of a teiHeader element as its separate page, or in the jinntap editor.

## Stand-alone

The editor is available as a stand-alone version. It has its own page. This is intended
for big forms where there are many separate fields that require visual space.

## In jinn-tap

The editor also integrates with jinn-tap. This is intended for few fields where it makes
sense to edit them alongside the body of a manuscript.

## Customization

The profile comes with a basic example that edits the title of a document, and the author(s). This
is meant as an axample that can be customized later on.

The changes should be made in the `form.html` file, where Fore is used to define a form for the
teiHeader. To add for example an input field for the `teiHeader/sourceDesc/bibl` element, add
something like this to add editing capabilites for it.

```html
<fieldset>
  <label>Source Description</label>
  <fx-control ref="/TEI/teiHeader/sourceDesc/bibl"></fx-control>
</fieldset>
```


