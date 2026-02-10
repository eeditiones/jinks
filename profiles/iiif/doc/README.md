The IIIF (International Image Interoperability Framework) integration allows you to display high-resolution images with zooming and panning capabilities directly in your pages. This is particularly useful for displaying manuscripts, maps, artwork, or other detailed visual materials.

The profile also adds an API endpoint for generating IIIF presentation manifests. This is not relevant if you already have manifests available, but if not, it can generate one on the fly by inspecting the TEI. See below for more information.

## Configuration

The IIIF feature can be configured under the `features.iiif` section in the `config.json` of you app or in the frontmatter section of an HTML template:

```json
"features": {
    "iiif": {
        "viewer": "pb-tify",
        "base_uri": "https://apps.existsolutions.com/cantaloupe/iiif/2/",
        "type": "iiif",
        "enabled": true,
        "milestone_xpath": "//tei:pb",
        "replace_facs": {
            "regex": "^[^:]+:(.*)",
            "replace": "$1"
        }
    }
}
```

For example, the `facsimile.html` template uses frontmatter only to configure the IIIF viewer, disable the table of contents and set an initial size for the facsimile sidebar. This template is used to display Shakespeare's Romeo and Juliet in the main TEI Publisher demo app:

```html
<template>
    ---json
    {
        "templating": {
            "extends": "templates/pages/basic.html"
        },
        "features": {
            "toc": {
                "enabled": false
            },
            "iiif": {
                "viewer": "pb-tify",
                "enabled": true
            }
        },
        "theme": {
            "layout": {
                "after-width": "33vw"
            }
        }
    }
    ---
</template>
```

### Available Options

- `enabled`: Set to `true` to activate the IIIF viewer on the page
- `viewer`: Specifies which IIIF viewer to use, currently `pb-tify` or `pb-facsimile`
- `type`: Using `pb-facsimile` it is also possible to load images from an URL instead of using IIIF. In this case, set `type` to `image`.
- `base_uri`: Specifies the base URI for the IIIF image API. This is only relevant for the `pb-facsimile` viewer. `pb-tify` will get this information from the manifest.

### Viewers

* `pb-facsimile`: A viewer implementing the IIIF image API for viewing one or more images. The names/paths of those images need to be known beforehand and should be registered with the component via pb-facs-link or custom javascript. The viewer is based on [OpenSeadragon](https://openseadragon.github.io/).
* `pb-tify`: Supports IIIF presentation manifests: instead of registering a list of images, it expects all relevant metadata - including the list of images - to be provided in a single, standardized manifest. Under the hood, pb-tify is based on [tify](https://tify.rocks/), which also uses OpenSeadragon for the image display functionality. Available since version 2.10.0 of tei-publisher-components.

Both components are usually used in conjunction with the `pb-facs-link` component (output via ODD) to register the image or manifest URLs to be displayed.

## Layout Considerations

When using the IIIF viewer, you may want to adjust the layout to accommodate the viewer interface. In the facsimile template example, the `after-width` is set to provide adequate space:

```json
"theme": {
    "layout": {
        "after-width": "33vw"
    }
}
```

This allocates 33% of the viewport width to the sidebar area, leaving more space for the main content area where the IIIF viewer will be displayed.

## IIIF Manifest Generation

The profile also provides an endpoint for generating a IIIF manifest on the fly, which can then be fed to the `pb-tify` viewer. The Shakespeare example in the _documentation and demo_ profile uses this endpoint. The endpoint will listen on `/api/iiif/{path}`, where _path_ is the relative path to the TEI document.

To generate a manifest from a TEI document, the endpoint implementation will walk through all `<pb>` in the document, using the `@facs` attribute to resolve images. If the `@facs` attribute starts with a `#`, we assume it points to a `<facsimile>` or `<surface>`, which has a `<graphic>` descendant. The `@url` attribute of the `<graphic>` element is then used as the image URL.

In all other cases, the `@facs` will be interpreted as an URL relative to the `base_uri`. Because it is common practice to prefix such URLs, we additionally run the value through a regular expression to normalize it. The regular expression is defined in the `replace_facs` option.

The endpoint will also contact the configured image api service (deterimined by the `base_uri` setting) to retrieve measurements for each image. This is required for the IIIF manifest to be valid.

## Integration with Jinntap editor profile

This profile can integrate with the Jinntap profile. It extracts the facsimile locations from the TEI XML, and links the `pb` elements to the facsimile viewer. It requires using the pb-facsimile viewer, the pb-tify viewer is not supported.

## Credits

This feature has been primarily funded via [Jagiellonian Digital Platform](https://labedyt.dhlab.uj.edu.pl/)

![dhlab](../../../resources/images/dhlab.svg)
