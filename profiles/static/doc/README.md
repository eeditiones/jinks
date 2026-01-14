# Static Profile Documentation

The static profile enables generation of a static HTML version of your TEI Publisher application. A static website consists of pre-generated HTML files that can be served by any web server. Unlike a dynamic website that generates pages on-demand (requiring a database and server-side processing), a static site has all the pages created in advance. This makes it cheap to host – you can even deploy it to free services like GitHub Pages, or any basic web hosting. And because the static generator creates a static snapshot of your application, it is a convenient way to obtain a copy for long-term preservation and archiving.

However, bear in mind that static versions come at a cost: there is no server-side indexing, so search and browsing possibilities will be very limited without facets or dynamic filtering. Everything needs to be pre-generated and the outcome will never be as feature-rich as the dynamic original. And due to the restrictions of a static version, you will need to adapt your HTML templates, and take precautions in the ODD to support both: the dynamic and static output. Unless you are planning to go for a static-only site, this means a bit of additional work.

In general, static generation will work best for rather small editions, e.g. a monograph or a correspondence with just a few dozen letters. TEI Publisher 10 demonstrates this with the Serafin correspondence: while examining the static output, you will notice that the browsing view is very simple, the letter by letter navigation is missing, etc. However, people and places registers are still available, and even a basic client-side search feature, albeit limited to simple by-word full text search.

## Try it

To generate a static version, the application needs to be prepared for it, i.e. it must have the required configuration and should provide adapted HTML templates for the static pages to be rendered.

To try this out:

1. start a new app using the _Serafin Correspondence_ blueprint
2. add the _Static generator_ feature
3. generate the app by clicking _Apply_
4. once completed, you should see an additional button _Generate static_ in the _Actions_ toolbar in Jinks
5. click on it and wait
6. open the generated application and select _Static Version_ from the _Administration_ menu

All files of the resulting static version will be written to a subcollection called `output` below the application root.

## Understanding Static Generation

The static profile generates HTML pages by:

1. Processing documents from configured collections
2. Paginating documents into multiple HTML pages
3. Creating browse/index pages for collections
4. Copying resources (CSS, images, scripts, etc.)
5. Generating search indexes
6. Fixing internal links between pages

This process is mainly configured in the `static` section of the `config.json`, though more complex tasks can be added via an XQuery module (as is the case for the people and places registers in the Serafin example).

### Output Structure

When the static generation completes, you will find a folder structure in the `output` subcollection below your application root. A typical output looks as follows:

```
output/
├── index.html                   # Redirects to the first browse page 
├── 1/                           # First browse page for a collection
│   └── index.html
├── 2/                           # Second browse page (if needed)
│   └── index.html
├── letters/                     # The contents of a collection
│   └── serafin01.xml            # Represents one document in the collection
│       ├── 1/                   # First page to display
│       │   └── index.html
│       └── 2/                   # Second page to display
│           └── index.html
├── resources/                   # Copied resources
│   ├── css/                     # Stylesheets
│   ├── images/                  # Images
│   ├── scripts/                 # JavaScript files
│   └── i18n/                    # Translation files
├── images/                      # Additional copied images (from "copy" config)
├── transform/                   # ODD-generated CSS files
└── index.jsonl                  # Search index (if enabled)
```

### Templates and Customization

TBD

## Configuration

The static profile is configured through the `static` section in your `config.json` file. The configuration supports the following options:

### Basic Structure

```json
{
  "static": {
    "templating": { ... },
    "collections": { ... },
    "styles": [ ... ],
    "fields": { ... },
    "copy": [ ... ],
    "redirect": { ... },
    "facets": [ ... ]
  }
}
```

## Configuration Options

### `templating`

Specifies additional template definitions to use when expanding blocks during static generation.

**Properties:**
- `use` (array of strings): List of template definition files to consult when expanding blocks

**Example:**
```json
"templating": {
  "use": [
    "templates/iiif-blocks.html",
    "static/templates/register-static-blocks.html"
  ]
}
```

These templates are merged with the main templating configuration and used during template processing.

### `collections`

Defines one or more collections to generate static pages for. Each collection is configured with its own settings.

**Collection Key:**
- The key can be a collection name (e.g., `"doc"`, `"demo"`) or an empty string `""` for the root/default collection
- An empty string key processes documents from the default data collection

**Collection Configuration Properties:**

#### `path-prefix` (string, optional)
Optional prefix to prepend to the output path before the relative collection path. Defaults to `"documents"` if not specified.

**Example:**
```json
"path-prefix": "letters"
```

#### `index` (string | boolean)
Controls whether a search index is generated for the collection.
- `false`: No index is created
- `"single"`: Creates a single index entry per document
- `true` or other string: Creates an index using the specified method

**Example:**
```json
"index": false
```
or
```json
"index": "single"
```

#### `template` (string, required)
The template to use for rendering the collection browse/index pages. Path is relative to the application root.

**Example:**
```json
"template": "static/templates/index.html"
```

#### `include` (array of strings, optional)
Optional list of specific documents to include in the static generation. If not specified, all documents in the collection will be included.

**Example:**
```json
"include": ["demo/F-rom.xml"]
```

#### `paginate` (object, optional)
Configuration for how documents are paginated into multiple HTML pages.

**Properties:**
- `template` (string, required): The template to use for rendering each page
- `toc` (boolean, required): If `true`, a table of contents will be generated for the document
- `parts` (array, required): List of parts to render for each page

**Part Configuration:**
Each part in the `parts` array can have the following properties:
- `id` (string, optional): A name for the part. If not specified, `"default"` is used. Parts are available in templates via `$parts?<id>`, e.g., `$parts?default`
- `odd` (string, optional): The ODD to use for transforming this part
- `view` (string, optional): The view mode (`"div"`, `"page"`, or `"single"`)
- `xpath` (string, optional): XPath expression to select specific content from the document
- `user.mode` (string, optional): Special processing mode (e.g., `"breadcrumb"`, `"register"`)

**Example:**
```json
"paginate": {
  "template": "static/templates/documentation.html",
  "toc": true,
  "parts": [
    {
      "odd": "docbook.odd"
    },
    {
      "id": "breadcrumb",
      "user.mode": "breadcrumb",
      "odd": "docbook.odd"
    }
  ]
}
```

**More Complex Example:**
```json
"paginate": {
  "template": "static/templates/serafin.html",
  "toc": false,
  "parts": [
    {
      "odd": "serafin.odd",
      "view": "single",
      "xpath": "//text[@type = 'source']"
    },
    {
      "id": "translation",
      "xpath": "//text[@type = 'translation']",
      "odd": "serafin.odd",
      "view": "single"
    },
    {
      "id": "breadcrumb",
      "view": "single",
      "odd": "serafin.odd",
      "user.mode": "breadcrumb"
    }
  ]
}
```

#### `fetch` (array, optional)
Fetches resources from URLs and stores them in the static output. Useful for downloading external resources like IIIF manifests.

**Properties:**
- `url` (string, required): The URL to fetch. May contain template parameters like `[[$context?base-uri]]` and `[[$doc?path]]`
- `target` (string, required): The target path where the resource should be stored. May also contain template parameters.

**Example:**
```json
"fetch": [
  {
    "url": "[[$context?base-uri]]/api/iiif/[[$doc?path]]",
    "target": "[[$doc?path]]/manifest.json"
  }
]
```

**Complete Collection Example:**
```json
"collections": {
  "doc": {
    "path-prefix": "",
    "index": false,
    "template": "static/templates/index.html",
    "paginate": {
      "template": "static/templates/documentation.html",
      "toc": true,
      "parts": [
        {
          "odd": "docbook.odd"
        }
      ]
    }
  },
  "demo": {
    "path-prefix": "",
    "index": false,
    "include": ["demo/F-rom.xml"],
    "template": "static/templates/index.html",
    "fetch": [
      {
        "url": "[[$context?base-uri]]/api/iiif/[[$doc?path]]",
        "target": "[[$doc?path]]/manifest.json"
      }
    ],
    "paginate": {
      "template": "static/templates/facsimile.html",
      "toc": false,
      "parts": [
        {
          "id": "default",
          "view": "page",
          "odd": "shakespeare.odd"
        }
      ]
    }
  }
}
```

### `styles`

List of CSS stylesheets to include in each static page. Paths are relative to the application root.

**Example:**
```json
"styles": [
  "resources/css/static.css",
  "transform/docbook.css",
  "transform/serafin.css"
]
```

### `fields`

Configures which fields are indexed and stored for search functionality.

**Properties:**
- `index` (array of strings): Fields to include in the search index
- `store` (array of strings): Fields to store in the index for retrieval

**Example:**
```json
"fields": {
  "index": ["content", "translation", "commentary"],
  "store": ["content", "translation", "commentary", "title", "link", "places"]
}
```

### `facets`

List of facet names to include in the search index. Facets enable filtering search results by specific metadata fields.

**Example:**
```json
"facets": ["places"]
```

### `copy`

Copies resources from source paths to target paths in the static output. Useful for copying images, data files, or other resources.

**Properties:**
- `from` (string, required): The source path relative to the application root
- `to` (string, required): The target path relative to the static output collection
- `filter` (string, optional): Regular expression filter to apply when copying files

**Example:**
```json
"copy": [
  {
    "from": "data/doc",
    "to": "images",
    "filter": "\\.(?:png|jpg|jpeg|gif|svg)$"
  }
]
```

This copies all image files from `data/doc` to the `images` directory in the static output.

### `redirect`

Creates HTML redirect pages. The key is the source path, the value is the target URL to redirect to.

**Example:**
```json
"redirect": {
  "": "1/index.html"
}
```

This creates a redirect from the root path to `1/index.html`.

## Complete Example

Here's a complete example combining multiple configuration options:

```json
{
  "static": {
    "templating": {
      "use": [
        "templates/iiif-blocks.html"
      ]
    },
    "collections": {
      "doc": {
        "path-prefix": "",
        "index": false,
        "template": "static/templates/index.html",
        "paginate": {
          "template": "static/templates/documentation.html",
          "toc": true,
          "parts": [
            {
              "odd": "docbook.odd"
            },
            {
              "id": "breadcrumb",
              "user.mode": "breadcrumb",
              "odd": "docbook.odd"
            }
          ]
        }
      }
    },
    "styles": [
      "resources/css/static.css",
      "transform/docbook.css"
    ],
    "fields": {
      "index": ["content"],
      "store": ["content", "title", "link"]
    },
    "copy": [
      {
        "from": "data/doc",
        "to": "images",
        "filter": "\\.(?:png|jpg|jpeg|gif|svg)$"
      }
    ]
  }
}
```

## Template Variables

When rendering templates, the following variables are available:

- `$parts`: Map containing all configured parts, accessible via `$parts?<id>` (e.g., `$parts?default`, `$parts?breadcrumb`)
- `$parts?<id>?content`: The main content of a part (as XML)
- `$parts?<id>?footnotes`: Footnotes for a part (as XML)
- `$parts?<id>?next`: Path to the next page (if available)
- `$parts?<id>?prev`: Path to the previous page (if available)
- `$pagination`: Map containing pagination information
  - `$pagination?page`: Current page number
- `$table-of-contents`: Table of contents structure (if `toc: true`)
- `$context`: Full context map with application configuration