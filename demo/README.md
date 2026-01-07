# Demo Apps

This directory contains configuration files and a Dockerfile for building a container image with pre-generated demo applications.

## Purpose

The demo container (`ghcr.io/eeditiones/jinks-demo`) includes three pre-generated TEI Publisher applications:

- **tei-publisher** - Full-featured TEI Publisher application with demo data, documentation, and all standard features
- **tp-serafin** - Serafin correspondence edition with registers, timeline, and edition navigation
- **tp-annotator** - Annotation workbench with Jinntap editor integration

## Configuration Files

- `tp_config.json` - Configuration for tei-publisher app
- `ser_config.json` - Configuration for tp-serafin app
- `ann_config.json` - Configuration for tp-annotator app

## Build Process

The demo container is automatically built by the CI workflow (`.github/workflows/demo-apps.yml`) on:

- **Push to any branch** - Generates apps and builds image (for testing)
- **Release tags (v*)** - Generates apps, builds, and pushes versioned images to GHCR

The workflow:
1. Starts a jinks container
2. Uses jinks-cli to generate apps from the config files
3. Downloads XAR files for each generated app
4. Builds a Docker image using `Dockerfile.demo`
5. (On tags only) Pushes the image to `ghcr.io/eeditiones/jinks-demo:{version}`

## Usage

Pull and run the demo container:

```bash
docker pull ghcr.io/eeditiones/jinks-demo:latest
docker run -p 8080:8080 ghcr.io/eeditiones/jinks-demo:latest
```

Access the applications:
- tei-publisher: http://localhost:8080/exist/apps/tei-publisher/
- tp-serafin: http://localhost:8080/exist/apps/tp-serafin/
- tp-annotator: http://localhost:8080/exist/apps/tp-annotator/

## Local Development

To build the demo container locally:

1. Generate the XAR files using jinks-cli against a running jinks instance
2. Place the XAR files in this directory
3. Build the image:
   ```bash
   docker build -f Dockerfile.demo -t jinks-demo:local .
   ```

