#!/bin/bash

# Step into script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# PRODUCTION=true: use published jinks image, tp_config.prod.json (view-static + sitemap),
# pre-generate/upload documentation into cached/, and run the sitemap action.
# Default (unset/false): build jinks from this checkout and use tp_config.json
# without static mode — suitable when opm is not available (e.g. matching CI).
PRODUCTION="${PRODUCTION:-false}"

# Check if npx is available
if ! command -v npx &> /dev/null; then
    echo "Error: npx command not found. Please install Node.js and npm."
    exit 1
fi

if [ "$PRODUCTION" = "true" ]; then
    # Check if opm is available (pre-generates documentation pages)
    if ! command -v opm &> /dev/null; then
        echo "Error: opm command not found. Please install the Open Processing Model."
        exit 1
    fi

    # Check if xst is available (uploads pre-generated content into eXist)
    if ! command -v xst &> /dev/null; then
        echo "Error: xst command not found. Please install @existdb/xst (npm install -g @existdb/xst)."
        exit 1
    fi
fi

# Check if port 8080 is already in use
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Error: Port 8080 is already in use."
    echo "Please stop the service using port 8080 or choose a different port."
    echo ""
    echo "Process using port 8080:"
    lsof -Pi :8080 -sTCP:LISTEN
    exit 1
fi

# Use npx to run the latest version of @teipublisher/jinks-cli
JINKS_CMD="npx @teipublisher/jinks-cli"

if [ "$PRODUCTION" = "true" ]; then
    echo "PRODUCTION=true: using ghcr.io/eeditiones/jinks:latest and tp_config.prod.json"
    docker pull ghcr.io/eeditiones/jinks:latest
    JINKS_IMAGE="ghcr.io/eeditiones/jinks:latest"
    TP_CONFIG="tp_config.prod.json"
else
    # Build jinks from this checkout (same as CI). Pulling ghcr.io/eeditiones/jinks:latest
    # leaves the image's already-installed profiles in place, so `jinks create` would keep
    # generating apps from stale templates/config even when this repo has newer ones.
    echo "PRODUCTION=false: building local jinks image and using tp_config.json"
    docker build -t jinks-server:local -f ../Dockerfile --build-arg EXIST_VERSION=6.4.0 ..
    JINKS_IMAGE="jinks-server:local"
    TP_CONFIG="tp_config.json"
fi

# Remove existing container if it exists (running or stopped)
if docker ps --format '{{.Names}}' | grep -q '^jinks-server$'; then
    echo "Stopping and removing existing container 'jinks-server'..."
    docker stop jinks-server
    docker rm jinks-server
elif docker ps -a --format '{{.Names}}' | grep -q '^jinks-server$'; then
    echo "Removing existing stopped container 'jinks-server'..."
    docker rm jinks-server
fi

# Create new container
echo "Creating new container 'jinks-server'..."
docker run -d --name jinks-server -p 8080:8080 "$JINKS_IMAGE"

# Wait for server to be ready
echo "Waiting for eXist-db to start..."
timeout=120
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if curl -s -f http://localhost:8080/exist/apps/jinks/api/configurations > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    echo "Still waiting... ($elapsed seconds)"
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ $elapsed -ge $timeout ]; then
    echo "Timeout waiting for server"
    exit 1
fi

echo "Creating apps..."
$JINKS_CMD create -c "$TP_CONFIG"
$JINKS_CMD create -c ser_config.json
$JINKS_CMD create -c workbench_config.json
$JINKS_CMD create -c jats_config.json

$JINKS_CMD list

if [ "$PRODUCTION" = "true" ]; then
    # Pre-generate documentation pages for tei-publisher (pb-view static mode)
    # and upload them into the app's cached/ collection before packaging the XAR.
    # See tei-publisher-py docs/guide/tei-publisher.md
    DOCS_DATA="../profiles/docs/data/doc"
    echo "Pre-generating documentation pages with opm..."
    opm chunk "$DOCS_DATA" -c opm.toml --format pb-view --force

    echo "Uploading pre-generated content into tei-publisher..."
    xst upload chunks/ /db/apps/tei-publisher/cached/ -v

    echo "Generating sitemap.xml..."
    $JINKS_CMD run tei-publisher sitemap
fi

$JINKS_CMD run tei-publisher download
$JINKS_CMD run tp-serafin download
$JINKS_CMD run tp-workbench download
$JINKS_CMD run tp-jats download

docker stop jinks-server

docker build -f Dockerfile.demo -t jinks-demo .
