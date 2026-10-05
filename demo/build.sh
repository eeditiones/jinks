#!/bin/bash

# Step into script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DODIS_WALL="${DODIS_WALL:-../../dodis-wall}"

# PRODUCTION=true: use tp_config.prod.json (view-static + sitemap), pre-generate/upload
# documentation into cached/, and run the sitemap action. Uses the published
# ghcr.io/eeditiones/jinks:latest image unless LOCAL=true.
# Default (unset/false): build jinks from this checkout and use tp_config.json
# without static mode — suitable when opm is not available (e.g. matching CI).
PRODUCTION="${PRODUCTION:-false}"
# LOCAL=true: in production mode, build the jinks image from this checkout
# (../Dockerfile, with its bundled dependencies) instead of pulling latest.
# This applies both to the server generating the apps and to the base of the
# final demo image.
LOCAL="${LOCAL:-false}"
EXIST_VERSION="${EXIST_VERSION:-6.4.0}"

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
    TP_CONFIG="tp_config.prod.json"
else
    TP_CONFIG="tp_config.json"
fi

if [ "$PRODUCTION" = "true" ] && [ "$LOCAL" != "true" ]; then
    JINKS_LOCAL=false
    JINKS_IMAGE="ghcr.io/eeditiones/jinks:latest"
    echo "PRODUCTION=true: using $JINKS_IMAGE and $TP_CONFIG"
    docker pull "$JINKS_IMAGE" || { echo "Error: could not pull $JINKS_IMAGE"; exit 1; }
else
    # Build jinks from this checkout (same as CI). Pulling ghcr.io/eeditiones/jinks:latest
    # leaves the image's already-installed profiles in place, so `jinks create` would keep
    # generating apps from stale templates/config even when this repo has newer ones.
    # --pull refreshes the base images (builder, existdb) instead of reusing stale local copies.
    # The final demo image is built on the same checkout via docker-bake.hcl.
    JINKS_LOCAL=true
    JINKS_IMAGE="jinks-server:local"
    echo "PRODUCTION=$PRODUCTION: building local jinks image, using $TP_CONFIG"
    docker build --pull -t "$JINKS_IMAGE" -f ../Dockerfile --build-arg EXIST_VERSION="$EXIST_VERSION" .. \
        || { echo "Error: docker build failed"; exit 1; }
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
    xst upload chunks/ /db/apps/tei-publisher/cached/

    echo "Generating sitemap.xml..."
    $JINKS_CMD run tei-publisher sitemap
fi

$JINKS_CMD run tei-publisher download
$JINKS_CMD run tp-serafin download
$JINKS_CMD run tp-workbench download
$JINKS_CMD run tp-jats download

docker stop jinks-server

# Optionally include the dodis-wall app if its checkout is available
if [ -d "$DODIS_WALL" ]; then
    if ! command -v ant &> /dev/null; then
        echo "Error: ant command not found, required to build $DODIS_WALL."
        exit 1
    fi
    echo "Building dodis-wall XAR in $DODIS_WALL..."
    (cd "$DODIS_WALL" && ant) || { echo "Error: ant build failed in $DODIS_WALL"; exit 1; }
    rm -f wall-came-down-*.xar
    cp "$DODIS_WALL"/build/*.xar .
else
    echo "dodis-wall not found at $DODIS_WALL, skipping."
fi

# Final demo image
# IMAGE:     tag to build/push (default: jinks-demo)
# PLATFORMS: e.g. linux/amd64,linux/arm64 — multi-arch via buildx (requires PUSH=true)
# PUSH:      if true, push to the registry
IMAGE="${IMAGE:-jinks-demo}"
PLATFORMS="${PLATFORMS:-}"
PUSH="${PUSH:-false}"

if [ -n "$PLATFORMS" ] && [ "$PUSH" != "true" ]; then
    echo "Error: multi-arch builds (PLATFORMS set) require PUSH=true;"
    echo "Docker cannot load a multi-platform image into the local image store."
    echo "Example: IMAGE=wolfgangmm/tei-publisher-home:latest PLATFORMS=linux/amd64,linux/arm64 PUSH=true ./build.sh"
    exit 1
fi

if [ "$JINKS_LOCAL" = "true" ]; then
    # Only the demo target gets an output; the jinks target is consumed as its base.
    if [ -n "$PLATFORMS" ]; then
        echo "Building multi-arch image ($PLATFORMS) on local jinks and pushing as $IMAGE..."
        OUTPUT="type=registry"
    else
        echo "Building image $IMAGE on local jinks..."
        OUTPUT="type=docker"
    fi
    IMAGE="$IMAGE" PLATFORMS="$PLATFORMS" EXIST_VERSION="$EXIST_VERSION" \
        docker buildx bake -f docker-bake.hcl --allow=fs.read=.. --set "demo.output=$OUTPUT" demo \
        || { echo "Error: docker buildx bake failed"; exit 1; }
    if [ -z "$PLATFORMS" ] && [ "$PUSH" = "true" ]; then
        echo "Pushing $IMAGE..."
        docker push "$IMAGE"
    fi
elif [ -n "$PLATFORMS" ]; then
    echo "Building multi-arch image ($PLATFORMS) and pushing as $IMAGE..."
    docker buildx build \
        --pull \
        --platform "$PLATFORMS" \
        -f Dockerfile.demo \
        -t "$IMAGE" \
        --push \
        .
else
    echo "Building image $IMAGE..."
    docker build --pull -f Dockerfile.demo -t "$IMAGE" .
    if [ "$PUSH" = "true" ]; then
        echo "Pushing $IMAGE..."
        docker push "$IMAGE"
    fi
fi
