#!/bin/bash

# Step into script dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if npx is available
if ! command -v npx &> /dev/null; then
    echo "Error: npx command not found. Please install Node.js and npm."
    exit 1
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

docker pull ghcr.io/eeditiones/jinks:latest

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
docker run -d --name jinks-server -p 8080:8080 ghcr.io/eeditiones/jinks:latest

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
$JINKS_CMD create -c tp_config.json
$JINKS_CMD create -c ser_config.json
$JINKS_CMD create -c workbench_config.json

$JINKS_CMD list

$JINKS_CMD run tei-publisher download
$JINKS_CMD run tp-serafin download
$JINKS_CMD run tp-workbench download

docker stop jinks-server

docker build -f Dockerfile.demo -t jinks-demo .
