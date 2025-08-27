# CSS layout

* We now use one CSS layout for all pages.
* The layout uses a grid with defined areas:
    * header (menubar)
    * before-top, before
    * content-top, content
    * after-top, after
* In the default grid, *before* and *after* refer to left and right sidebar areas. However, this can change, e.g. if you are in a rtl language context.
* The left and right sidebar can be collapsed (button added automatically) and are best suited for things like table of contents, register of places/people, or a facsimile viewer.
* The main content uses a horizontal flex layout, which means it can host more than one thing, e.g. the transcription and the translation for the *registers* profile.

# Templating blocks

* To populate any of the areas, your HTML template view can push content to the corresponding block.
* Most page templates will extend [`profiles/base10/templates/content.html`](https://github.com/eeditiones/jinks/blob/main/profiles/base10/templates/layouts/content.html), which again extends [`base.html`](https://github.com/eeditiones/jinks/blob/main/profiles/base10/templates/layouts/base.html).

**Examples from the codebase:**

### 1. Adding a timeline to the right sidebar (timeline profile)
In [`profiles/timeline/templates/timeline-blocks.html`](https://github.com/eeditiones/jinks/blob/main/profiles/timeline/templates/timeline-blocks.html):
```html
[% template after %]
[% if exists($context?doc) and $features?timeline?document-view %]
<div class="timeline">
    <pb-timeline url="[[ $context-path ]]/api/timeline/[[ $context?doc?path ]]" auto=""
        scopes="[&#34;D&#34;, &#34;M&#34;, &#34;Y&#34;, &#34;5Y&#34;, &#34;10Y&#34;]"
        resettable="" max-interval="80" subscribe="corresp-timeline" emit="corresp-timeline"
    >
        <span slot="label">Angezeigter Zeitraum: </span>
    </pb-timeline>
</div>
[% endif %]
[% endtemplate %]
```

### 2. Register and map in the sidebar (registers profile)
In [`profiles/registers/templates/register-blocks.html`](https://github.com/eeditiones/jinks/blob/main/profiles/registers/templates/register-blocks.html):
```html
[% template after %]
[% if $context?features?register?enabled and exists($context?doc)%]
<pb-view src="document1" subscribe="transcription" view="[[ $context?doc?view ]]" disable-history="">
    <pb-param name="mode" value="register" />
</pb-view>
<pb-leaflet-map id="map" zoom="11" subscribe="map">
    <pb-map-layer show="" base="" label="OpenTopo Map"
        url="https://{s}.tile.openstreetmap.de/tiles/osmde/{z}/{x}/{y}.png" max-zoom="19"
        attribution="© &lt;a href=&quot;https://www.openstreetmap.org/copyright&quot;>OpenStreetMap&lt;/a&gt; contributors"></pb-map-layer>
</pb-leaflet-map>
[% endif %]
[% endtemplate %]
```

### 3. Facsimile viewer in the right sidebar (docs profile)
In [`profiles/docs/templates/pages/facsimile.html`](https://github.com/eeditiones/jinks/blob/main/profiles/docs/templates/pages/facsimile.html):
```html
[% template after %]
<pb-tify subscribe="transcription" emit="transcription"></pb-tify>
[% endtemplate %]
```
