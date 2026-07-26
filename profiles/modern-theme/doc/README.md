# Modern theme

A contemporary visual theme for TEI Publisher 10. It extends [theme-base10](../theme-base10/doc/README.md) rather than replacing it: all layout, component structure, and CSS custom-property hooks come from the default Jinks theme; this profile layers typography, colour, and flat rectangular controls on top.

Edition-specific chrome (for example the parchment toolbar band and breadcrumb title treatment in the Serafin blueprint) belongs in the consuming profile, not here.

## Using the theme

Add **both** `theme-base10` and `modern-theme` to your application's `extends` list (or select them on the **Themes** tab in Jinks). `modern-theme` depends on `theme-base10`; the base theme must remain present because it supplies the core stylesheets, palettes, and generator hooks.

```json
"extends": [
  "base10",
  "theme-base10",
  "modern-theme"
]
```

Blueprints that declare a dependency on `modern-theme` (for example the Serafin blueprint) will auto-select it when chosen in the profile picker.

## How it differs from theme-base10

### Configuration (`config.json`)

The profile merges these defaults into the app configuration (later profiles and your own `config.json` can override them):

| Setting | theme-base10 | modern-theme |
|---------|--------------|--------------|
| `theme.colors.palette` | `neutral` | `beige` |
| `theme.fonts.base.family` | Inter | Albert Sans |
| `theme.fonts.content.family` | JunicodeVF, Georgia, … | Albert Sans |
| `theme.fonts.content.size` | `1.25rem` | `1.2rem` |
| `theme.fonts.heading.family` | Inter | Albert Sans |
| `theme.fonts.heading.weight` | `600` | `600` |
| `theme.content.max-width` | `70ch` | `48ch` |
| `theme.components.styles` | — | `resources/css/modern-theme-components.css` |

Logo, splash image, layout options, texture, and breadcrumb styling are typically set by the consuming blueprint—for example the Serafin blueprint adds its parchment toolbar band, icon, animation, and browse layout on top of this theme.

### Fonts

`theme-base10` ships Inter and JunicodeVF in `resources/fonts/font.css`. **modern-theme replaces that file** with locally hosted [Albert Sans](https://fonts.google.com/specimen/Albert+Sans) (variable, latin + latin-ext) for UI, content, and headings. No Google Fonts CDN request is made at runtime; faces are loaded via `jinks-theme.css` → `../fonts/font.css`. Edition-specific display faces (for example Belleza in the Serafin blueprint) belong in the consuming profile.

### Stylesheets

| File | Role |
|------|------|
| `resources/css/modern-theme.css` | Light-DOM overrides: CSS variables, segmented controls, browse cards, landing-page rectangular chrome, register sidebar |
| `resources/css/modern-theme-components.css` | Shadow-DOM overrides for `pb-lang`, `pb-login`, and `pb-search` (appended to `components.css` by the theme-base10 generator) |

Both load **after** the theme-base10 bundle, so they override only what is needed instead of forking `jinks-components.css` or `layouts.css`.

### Visual language

Compared to the rounded, neutral default theme, modern-theme applies:

- **Flat rectangular controls** — `2px` / `0` border radius on forms, toolbar segments, labelled action buttons, and landing-page CTA buttons (replacing pills and soft corners).
- **Segmented toolbar** — icon groups (`pb-zoom`, `pb-navigation`, edition-navigation) are square cells with hairline dividers; hover uses a burgundy accent (`#8a0000`). Labelled navigation buttons grow to fit their text.
- **Menubar chrome** — search, language, and login controls use flat hairline-bordered chips consistent with the toolbar.
- **Browse & document chrome** — flat document cards (no shadow), full-width main column, styled `aside.after` for tabbed registers/maps.
- **Landing pages** — when combined with the landing-page profile, keeps a rectangular menubar shell and flat `.button-link` CTAs without restyling nav links as chips.

### Assets

This theme does not ship edition logos. Consuming blueprints supply their own images under `resources/images/` (see the Serafin blueprint for an example).

## Customization

Most frequent tweaks belong in the app's `config.json` under `theme` (palette, fonts, content width)—the same keys documented for [theme-base10](../theme-base10/doc/README.md).

For visual details not exposed in JSON, edit the CSS custom properties at the top of `resources/css/modern-theme.css` (they map to hooks defined in `theme-base10/resources/css/jinks-variables.tpl.css`). Web-component internals go in `modern-theme-components.css`.

After changing the profile, regenerate and redeploy the consuming application so `font.css`, `components.css`, and copied assets are refreshed.

## Credits

Visual design developed for the [Correspondence of Mikołaj Serafin](https://e-editiones.org/) edition at the Jagiellonian University Digital Humanities Lab.
