# Upload Facility

This feature adds a component to the sidebar to allow logged in users to upload documents to a collection.

## Configuration

```json
"features": {
    "upload": {
        "enabled": true,
        "target": null
    }
}
```

* `enabled`: set the `true` to display the component
* `target`: the target collection uploaded documents should be stored into. If not set or null, documents will be stored into the default data collection of the application.