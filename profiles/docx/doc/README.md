This feature lets your TEI Publisher app work with Microsoft Word documents in two directions:

- import DOCX into TEI (`docx.odd`)
- export TEI as DOCX (`docx` output mode)

# DOCX2TEI Import

Please refer to the section [MS Word DOCX format conversion](https://teipublisher.org/doc/documentation.xml?id=docx#docx) in the documentation.

# DOCX Export

## How DOCX export works (in plain language)

When you export to DOCX, TEI Publisher does **not** create a Word file from scratch.
It starts from your chosen template and then inserts your TEI document content into it.

Think of it like this:

- the template provides the "look" (fonts, headings, margins, numbering definitions, etc.)
- your TEI provides the "text and structure" (headings, paragraphs, lists, notes, links, images)
- export merges both into a final `.docx`

This means the quality of the exported document strongly depends on the template styles.

## What comes from the template

From the template, export keeps core Word settings such as:

- paragraph and character styles
- page layout and section settings
- numbering definitions for lists
- document defaults (font tables, theme, settings)

In other words, your institutional Word design should live in the template.

## Choosing a DOCX template

Default template path:

`features.docx.template = "templates/docx/default.docx"`

Override it in your app config:

```json
{
  "features": {
    "docx": {
      "template": "templates/docx/my-template.docx"
    }
  }
}
```

## How TEI styles map to Word styles

During export, TEI classes specified in `cssClass` are matched to Word style IDs by name. For example:

```xml
<model output="docx" behaviour="paragraph" cssClass="Intro"/>
```

will be mapped to the Word style `Intro` if it exists in the template, otherwise export falls back to safe defaults (for example normal paragraph formatting).

The special style `Code` results in code formatting in the exported document, i.e. newlines and whitespace are preserved.

### Before/after text from ODD (`outputRendition`)

If your ODD defines scoped output renditions, content will be appended/prepended to the text. For example:

```xml
<model behaviour="inline">
    <outputRendition xml:space="preserve" scope="before">
    content: '[...]';
    </outputRendition>
</model>
```

## Common element behavior in DOCX export

In day-to-day use, these are the most important expectations:

- **Headings / paragraphs**: exported as real Word paragraphs
- **Lists**: nested lists are preserved; list type (numbered vs bullet) follows TEI list type
- **Footnotes**: exported as real Word footnotes
- **Line and page breaks**: exported as Word breaks (not plain text markers)
- **Hyperlinks**: exported as clickable links
- **Images**: embedded into the DOCX package
