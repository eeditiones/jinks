# Serafin theme

A parchment-and-ink visual theme for TEI Publisher 10. It extends [theme-base10](../theme-base10/doc/README.md) rather than replacing it: all layout, component structure, and CSS custom-property hooks come from the default Jinks theme; this profile layers typography, colour, texture, and flat rectangular controls on top.

## Using the theme

Add **both** `theme-base10` and `serafin-theme` to your application's `extends` list (or select them on the **Themes** tab in Jinks). `serafin-theme` depends on `theme-base10`; the base theme must remain present because it supplies the core stylesheets, palettes, and generator hooks.

```json
"extends": [
  "base10",
  "theme-base10",
  "serafin-theme"
]
```

Blueprints that declare a dependency on `serafin-theme` (for example the Serafin blueprint) will auto-select it when chosen in the profile picker.

## How it differs from theme-base10

### Configuration (`config.json`)

The profile merges these defaults into the app configuration (later profiles and your own `config.json` can override them):

| Setting | theme-base10 | serafin-theme |
|---------|--------------|---------------|
| `theme.colors.palette` | `neutral` | `beige` |
| `theme.texture.background-image` | none | `../images/parchment.png` |
| `theme.fonts.base.family` | Inter | Albert Sans |
| `theme.fonts.content.family` | JunicodeVF, Georgia, … | Albert Sans |
| `theme.fonts.content.size` | `1.25rem` | `1.2rem` |
| `theme.fonts.heading.family` | Inter | Belleza |
| `theme.fonts.heading.weight` | `600` | `400` |
| `theme.content.max-width` | `70ch` | `48ch` |
| `theme.breadcrumbs.max` | `40ch` | `none` |
| `theme.components.styles` | — | `resources/css/serafin-theme-components.css` |

Logo, splash image, and layout options (sidebar width, tabbed `after` panel, search position, and so on) are typically set by the consuming blueprint—for example the Serafin blueprint adds its icon, animation, and browse layout on top of this theme.

### Fonts

`theme-base10` ships Inter and JunicodeVF in `resources/fonts/font.css`. **serafin-theme replaces that file** with locally hosted [Albert Sans](https://fonts.google.com/specimen/Albert+Sans) (variable, latin + latin-ext) and [Belleza](https://fonts.google.com/specimen/Belleza) (regular, latin + latin-ext). No Google Fonts CDN request is made at runtime; faces are loaded via `jinks-theme.css` → `../fonts/font.css`.

### Stylesheets

| File | Role |
|------|------|
| `resources/css/serafin-theme.css` | Light-DOM overrides: CSS variables, toolbar parchment band, segmented controls, browse cards, landing-page rectangular chrome, register sidebar |
| `resources/css/serafin-theme-components.css` | Shadow-DOM overrides for `pb-lang`, `pb-login`, and `pb-search` (appended to `components.css` by the theme-base10 generator) |

Both load **after** the theme-base10 bundle, so they override only what is needed instead of forking `jinks-components.css` or `layouts.css`.

### Visual language

Compared to the rounded, neutral default theme, serafin-theme applies:

- **Flat rectangular controls** — `2px` border radius on forms, menubar chips, toolbar segments, and landing-page buttons (replacing pills and soft corners).
- **Parchment texture** — a subtle paper background on the toolbar (gradient + `parchment.png`), referenced through `--jinks-texture-background`.
- **Segmented toolbar** — icon groups (`pb-zoom`, `pb-navigation`, edition-navigation) are square cells with hairline dividers; hover uses a burgundy accent (`#8a0000`). Labelled navigation buttons grow to fit their text.
- **Toolbar typography** — breadcrumb trail in uppercase Albert Sans; current title in Belleza with a light halo for readability on the textured band.
- **Menubar chrome** — search, language, and login controls use flat hairline-bordered chips consistent with the toolbar.
- **Browse & document chrome** — flat document cards (no shadow), full-width main column, styled `aside.after` for tabbed registers/maps.
- **Landing pages** — when combined with the landing-page profile, overrides pill-shaped menubar and `.button-link` styles to match the edition chrome.

### Assets

| Path | Purpose |
|------|---------|
| `resources/images/parchment.png` | Toolbar / texture background |
| `resources/images/base_icon_transparent_background.svg` | Default logo (often overridden by blueprint) |
| `resources/images/base_textlogo_transparent_background.svg` | Text logo for browse sidebar |
| `resources/images/base_logo_transparent_background.svg` | Full logo variant |

## Customization

Most frequent tweaks belong in the app's `config.json` under `theme` (palette, fonts, texture path, content width)—the same keys documented for [theme-base10](../theme-base10/doc/README.md).

For visual details not exposed in JSON, edit the CSS custom properties at the top of `resources/css/serafin-theme.css` (they map to hooks defined in `theme-base10/resources/css/jinks-variables.tpl.css`). Web-component internals go in `serafin-theme-components.css`.

After changing the profile, regenerate and redeploy the consuming application so `font.css`, `components.css`, and copied assets are refreshed.

## Credits

Visual design developed for the [Correspondence of Mikołaj Serafin](https://e-editiones.org/) edition at the Jagiellonian University Digital Humanities Lab.
