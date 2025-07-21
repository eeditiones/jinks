# CSS layout

* We now use one CSS layout for all pages.
* The layout uses a grid with defined areas:
    * header (menubar)
    * top-left, left
    * top-center, content
    * top-right, right
* The left and right sidebar can be collapsed (button added automatically) and are best suited for things like table of contents, register of places/people, or a facsimile viewer.
* The main content uses flex layout, which means it can host more than one thing, e.g. the transcription and the translation for the *registers* profile.

**Example:**  
In [`profiles/base10/templates/layouts/content.html`](https://github.com/eeditiones/jinks/blob/main/profiles/base10/templates/layouts/content.html), the grid areas and sidebar toggles are defined as follows:
```html
<nav class="top-left">
  <ul></ul>
  <ul>
    <li>
      <a class="aside-toggle" title="Hide" data-toggle=".left">
        <!-- SVG icon -->
      </a>
    </li>
  </ul>
</nav>
[% if $context?features?toc?enabled %]
<div class="left">
  <h5><pb-i18n key="document.contents">Contents</pb-i18n></h5>
  <pb-load class="toc" url="api/document/{doc}/contents?..."></pb-load>
</div>
[% endif %]
...
<nav class="top-right">
  <ul>
    <li>
      <a class="aside-toggle" title="Hide" data-toggle=".right">
        <!-- SVG icon -->
      </a>
    </li>
  </ul>
</nav>
```

# Templating blocks

* To populate one of the sidebars, your HTML template view can push content to the block named `sidebar`. Inside the block use CSS classes to either make the block display on the left or the right.
* Most page templates will extend [`profiles/base10/templates/content.html`](https://github.com/eeditiones/jinks/blob/main/profiles/base10/templates/layouts/content.html), which again extends [`base.html`](https://github.com/eeditiones/jinks/blob/main/profiles/base10/templates/layouts/base.html). It adds the buttons to collapse side panels and (optional) the table of contents to `base.html`.

**Examples from the codebase:**

### 1. Adding a timeline to the right sidebar (timeline profile)
In [`profiles/timeline/templates/timeline-blocks.html`](https://github.com/eeditiones/jinks/blob/main/profiles/timeline/templates/timeline-blocks.html):
```html
[% template sidebar %]
[% if exists($context?doc) and $features?timeline?document-view %]
<div class="timeline right">
  <pb-timeline url="[[ $context-path ]]/api/timeline/[[ $context?doc?path ]]" ...>
    <span slot="label">Angezeigter Zeitraum:&nbsp;</span>
  </pb-timeline>
</div>
[% endif %]
[% endtemplate %]
```

### 2. Register and map in the sidebar (registers profile)
In [`profiles/registers/templates/register-blocks.html`](https://github.com/eeditiones/jinks/blob/main/profiles/registers/templates/register-blocks.html):
```html
[% template sidebar %]
[% if $context?features?register?enabled and exists($context?doc)%]
<aside class="[[ $features?register?placement ]]">
  <pb-view src="document1" subscribe="transcription" view="[[ $context?doc?view ]]" disable-history="">
    <pb-param name="mode" value="register" />
  </pb-view>
  <pb-leaflet-map id="map" zoom="11">
    <pb-map-layer ...></pb-map-layer>
  </pb-leaflet-map>
</aside>
[% endif %]
[% endtemplate %]
```

### 3. Facsimile viewer in the right sidebar (docs profile)
In [`profiles/docs/templates/pages/facsimile.html`](https://github.com/eeditiones/jinks/blob/main/profiles/docs/templates/pages/facsimile.html):
```html
[% template sidebar %]
<nav class="top-right">
  <ul>
    <li>
      <a class="aside-toggle" title="Hide" data-toggle=".right">
        <!-- SVG icon -->
      </a>
    </li>
  </ul>
</nav>
<pb-tify class="right" subscribe="transcription" emit="transcription"></pb-tify>
[% endtemplate %]
```

---

These examples show how to use the `sidebar` block in your templates to add custom content to the left or right sidebars, leveraging the grid layout and built-in collapse functionality. If you need more examples or want to see how to add content to other blocks (like `above-content` or `below-content`), let me know!
