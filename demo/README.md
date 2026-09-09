# Demo Apps

This directory contains configuration files and a Dockerfile for building a container image with pre-generated demo applications.

## Purpose

The demo container (`ghcr.io/eeditiones/jinks-demo`) includes three pre-generated TEI Publisher applications:

- **tei-publisher** - TEI Publisher application with TEI Publisher and Jinks documentation and demo collection showcasing various types of documents, XML vocabularies and use case scenarios
- **tp-serafin** - Serafin correspondence edition with registers, timeline, and edition navigation
- **tp-workbench** - Annotation workbench with Jinntap editor integration

## Configuration Files

- `tp_config.json` - Configuration for tei-publisher app (CI / local default; no view-static)
- `tp_config.prod.json` - Same app with `data-static` / `view-static` for documentation (used when `PRODUCTION=true`)
- `ser_config.json` - Configuration for tp-serafin app
- `workbench_config.json` - Configuration for tp-annotator app

## Build Process

The demo container is automatically built by the CI workflow (`.github/workflows/demo-apps.yml`) on:

- **Push to any branch** - Generates apps and builds image (for testing)
- **Release tags (v*)** - Generates apps, builds, and pushes versioned images to GHCR

The workflow:
1. Builds a jinks image from this checkout and starts it
2. Uses jinks-cli to generate apps from the config files (`tp_config.json` without static mode)
3. Downloads XAR files for each generated app
4. Builds a Docker image using `Dockerfile.demo`
5. (On tags only) Pushes the image to `ghcr.io/eeditiones/jinks-demo:{version}`

### Local builds (`./build.sh`)

```bash
# Default: build jinks from this checkout, use tp_config.json (no opm)
./build.sh

# Production-style: published jinks image, tp_config.prod.json, opm chunk + upload
PRODUCTION=true ./build.sh
```

`PRODUCTION=true` requires Docker, `opm`, and `xst` on the PATH. Chunking is configured in `opm.toml`.

## Usage

Pull and run the demo container:

```bash
docker pull ghcr.io/eeditiones/jinks-demo:latest
docker run -p 8080:8080 ghcr.io/eeditiones/jinks-demo:latest
```

Access the applications:
- tei-publisher: http://localhost:8080/exist/apps/tei-publisher/
- tp-serafin: http://localhost:8080/exist/apps/tp-serafin/
- tp-workbench: http://localhost:8080/exist/apps/tp-workbench/

## Local Development

To build the demo container locally:

1. Generate the XAR files using jinks-cli against a running jinks instance
2. Place the XAR files in this directory
3. Build the image:
   ```bash
   docker build -f Dockerfile.demo -t jinks-demo:local .
   ```