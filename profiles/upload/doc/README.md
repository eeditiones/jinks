# The Upload Documents component

The Upload Documents feature adds a document upload component to the sidebar on the browse documents page, allowing users to upload documents directly to a specified collection.

## Overview

The upload component automatically appears in the sidebar of the browse documents page when:

- The feature is enabled in the configuration
- The current user belongs to the same group as the application (defined in `pkg.user.group`)

## Configuration

Enable the upload feature in your application's `config.json` or the frontmatter of a HTML template. Example:

```json
{
    "features": {
        "upload": {
            "enabled": true,
            "target": "playground"
        }
    }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Set to `true` to display the upload component |
| `target` | string \| null | `null` | Target collection for uploaded documents. If not set or null, documents will be stored in the default data collection |
| `accept` | string | `.xml, .tei, .odd, .docx, .md, .mei` | List of file extensions accepted for uploading |