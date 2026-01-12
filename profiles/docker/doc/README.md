# Docker Support

The Docker profile adds support for containerizing and running your TEI Publisher application using Docker. It generates both a production `Dockerfile` and a development container configuration for VS Code.

## Overview

When the Docker profile is selected, it generates:

1. **A `Dockerfile`** for building production or development Docker images:
   - Builds your application and its dependencies (jinks-templates, tei-publisher-lib) inside a container
   - Downloads and installs required EXPATH packages (roaster, jwt, crypto)
   - Supports additional external XAR packages from public or private repositories
   - Creates a production-ready Docker image based on eXist-db
   - Configures ports, environment variables, and JVM options

2. **A VS Code devcontainer configuration** (`.devcontainer/`) for local development:
   - Pre-configured development environment with eXist-db
   - Optional support for Node.js, NER (Named Entity Recognition), TeX/LaTeX, and XST
   - Automatic installation and deployment of your application
   - VS Code extensions for eXist-db, XML, and OpenAPI

3. **BATS smoke tests** (`test/01-smoke.bats`) for verifying application health:
   - Tests container health and HTTP connectivity
   - Verifies package deployment and log cleanliness
   - Can be run locally or automatically in CI/CD workflows

The generated Dockerfile uses a multi-stage build process with two targets:
- `build_local`: Builds everything from source (for development)
- `build_prod`: Uses pre-built XAR packages from GitHub releases (for production)

## Configuration

The Docker profile can be configured in your application's `config.json`:

```json
{
    "docker": {
        "eXist": "6.4.0",
        "tei-publisher-lib": "6.0.2",
        "jinks-templates": "1.2.0",
        "roaster": "1.11.0",
        "jwt": "2.0.0",
        "crypto": "6.0.1",
        "ant": "1.10.15",
        "ports": {
            "http": 8080,
            "https": 8443
        },
        "features": {
            "nodejs": false,
            "xst": false,
            "ner": false,
            "tex": false
        },
        "externalXar": {
            "my-custom-package": "https://example.com/packages/my-custom-package.xar"
        }
    }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `eXist` | string | `6.4.0` | Version of eXist-db to use |
| `tei-publisher-lib` | string | `6.0.2` | Version of tei-publisher-lib |
| `jinks-templates` | string | `1.2.0` | Version of jinks-templates |
| `roaster` | string | `1.11.0` | Version of the roaster package |
| `jwt` | string | `2.0.0` | Version of the JWT package |
| `crypto` | string | `6.0.1` | Version of the crypto package |
| `ant` | string | `1.10.15` | Version of Apache Ant |
| `ports.http` | number | `8080` | HTTP port for the container |
| `ports.https` | number | `8443` | HTTPS port for the container |
| `features.nodejs` | boolean | `false` | Enable Node.js in devcontainer (for XST support) |
| `features.xst` | boolean | `false` | Install XST (XSLT Streaming Transformer) in devcontainer |
| `features.ner` | boolean | `false` | Install NER (Named Entity Recognition) service in devcontainer |
| `features.tex` | boolean | `false` | Install TeX/LaTeX distribution in devcontainer |
| `externalXar` | object | `{}` | Additional external XAR packages (see below) |

## External XAR Packages

The `externalXar` configuration allows you to specify additional XAR packages that should be downloaded and installed during the Docker build. This is useful for custom dependencies or packages not available in the public eXist-db repository.

### Public Packages

For packages available via public URLs, simply specify the URL:

```json
{
    "docker": {
        "externalXar": {
            "my-custom-package": "https://example.com/packages/my-custom-package.xar",
            "another-package": "https://example.com/packages/another-package.xar"
        }
    }
}
```

The key (e.g., `my-custom-package`) will be used as the filename in the Dockerfile (e.g., `my-custom-package.xar`).

### Private Packages

For packages hosted in private repositories (e.g., GitHub, GitLab), you can specify a token name that will be used with Docker BuildKit secrets:

```json
{
    "docker": {
        "externalXar": {
            "private-package": {
                "url": "https://github.com/your-org/private-repo/releases/download/v1.0.0/package.xar",
                "token": "GITHUB_TOKEN"
            }
        }
    }
}
```

When building the Docker image, you must provide the secret:

```bash
docker build --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN -t my-app .
```

**Note for GitHub Actions**: `GITHUB_TOKEN` is automatically provided by GitHub Actions for every workflow run. You can use `"token": "GITHUB_TOKEN"` directly in your `externalXar` configuration, and the CI workflow will automatically pass it as a BuildKit secret. No additional secret configuration is needed.

**Note for GitLab CI**: `CI_JOB_TOKEN` is automatically provided by GitLab CI for every job. You can use `"token": "CI_JOB_TOKEN"` directly in your `externalXar` configuration, and the CI workflow will automatically pass it as a BuildKit secret. Note that `CI_JOB_TOKEN` has limited scope (mainly for GitLab project access and package registries), so for external repositories (e.g., GitHub), you'll need to set up a custom CI/CD variable.

For local builds or other CI systems, the token name should match an environment variable that contains your authentication token. Docker BuildKit will securely pass this token during the build process without embedding it in the image layers.

## Building the Docker Image

### Local Build (Development)

To build a local development image that builds everything from source:

```bash
docker build --build-arg BUILD=local -t my-app:local .
```

### Production Build

To build a production image using pre-built XAR packages:

```bash
docker build --build-arg BUILD=prod -t my-app:prod .
```

### With Private Packages

If you have private packages configured, provide the secrets:

```bash
docker build \
    --build-arg BUILD=local \
    --secret id=github_token,env=GITHUB_TOKEN \
    -t my-app:local .
```

## Running the Container

### Basic Usage

```bash
docker run -p 8080:8080 my-app:local
```

The application will be available at `http://localhost:8080/exist/apps/<app-name>/index.html`.

### With Custom Ports

If you've configured custom ports in `config.json`:

```bash
docker run -p 8080:8080 -p 8443:8443 my-app:local
```

### With Environment Variables

You can override environment variables at runtime:

```bash
docker run -p 8080:8080 \
    -e NER_ENDPOINT=http://ner-service:8001 \
    -e CONTEXT_PATH=/my-app \
    -e PROXY_CACHING=true \
    my-app:local
```

### With JVM Options

To configure JVM memory and other options:

```bash
docker run -p 8080:8080 \
    -e JDK_JAVA_OPTIONS="-Xmx2g -Xms1g" \
    my-app:local
```

## Development Container (DevContainer)

The Docker profile also generates a VS Code devcontainer configuration that provides a complete development environment with eXist-db pre-installed and configured.

### Using the DevContainer

1. **Open in VS Code**: Open your project folder in VS Code
2. **Reopen in Container**: When prompted, click "Reopen in Container", or use the command palette (`F1` → "Dev Containers: Reopen in Container")
3. **Wait for Setup**: The container will build and automatically:
   - Install eXist-db
   - Install required packages (roaster, jwt, crypto, tei-publisher-lib)
   - Build your application
   - Deploy it to the local eXist-db instance

### DevContainer Features

The devcontainer supports optional features that can be enabled via the `docker.features` configuration:

- **Node.js** (`features.nodejs`): Installs Node.js for XST support
- **XST** (`features.xst`): Installs the XSLT Streaming Transformer (`@existdb/xst`) if both `nodejs` and `xst` are enabled
- **NER** (`features.ner`): Installs and runs a Named Entity Recognition service on port 8001
- **TeX/LaTeX** (`features.tex`): Installs a full TeX Live distribution for PDF generation

Example configuration with all features enabled:

```json
{
    "docker": {
        "features": {
            "nodejs": true,
            "xst": true,
            "ner": true,
            "tex": true
        }
    }
}
```

### DevContainer Ports

The devcontainer automatically forwards the configured HTTP and HTTPS ports. By default:
- `8080` (HTTP)
- `8443` (HTTPS)
- `8001` (NER service, if enabled)

### VS Code Extensions

The devcontainer automatically installs these VS Code extensions:
- `exist-db.existdb-vscode`: eXist-db integration
- `42crunch.vscode-openapi`: OpenAPI support
- `redhat.vscode-xml`: XML language support

## Smoke Tests

The Docker profile includes [BATS (Bash Automated Testing System)](https://bats-core.readthedocs.io/en/stable/) smoke tests that verify your application is running correctly. These tests are generated at `test/01-smoke.bats` and can be run against a running Docker container.

### Test Coverage

The smoke tests verify:

- **Container health**: JVM responds, container is healthy, server started cleanly
- **HTTP connectivity**: Container can be reached via HTTP on port 8080
- **Application deployment**: Package and dependencies are deployed correctly
- **Log cleanliness**: No errors, fatal errors, or warnings in logs

### Running the Tests

The tests expect a running Docker container named "exist" on port 8080:

```bash
# Start your container
docker run -dit -p 8080:8080 --name exist my-app:local

# Run the smoke tests
bats --tap test/01-smoke.bats
```

The tests automatically compute the expected number of deployed packages based on your application's expath dependencies configuration.

### Integration with CI/CD

These smoke tests are automatically executed in CI/CD workflows when the CI profile is enabled. See the [CI profile documentation](../ci/doc/README.md) for more information.

## Integration with CI/CD

The Docker profile is automatically selected when you choose the CI profile, ensuring that your CI/CD workflows can build and test your application in a containerized environment. The generated BATS smoke tests are automatically executed as part of the CI workflow. See the [CI profile documentation](../ci/doc/README.md) for more information.

## Requirements

- Docker (or compatible container runtime)
- Docker BuildKit (for private package support)
- Sufficient disk space for building the application and dependencies

## Notes

- The default admin password is empty (`""`). Change it after first startup for security.
- The Dockerfile uses `ONBUILD` instructions, so the image can be used as a base for custom builds.
- For production deployments, consider using the `build_prod` target which uses pre-built packages and a hardened exist-db.
