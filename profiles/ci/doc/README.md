# CI/CD Configuration

The CI profile adds continuous integration and continuous deployment (CI/CD) configuration files to your generated TEI Publisher application. It supports both GitHub Actions and GitLab CI/CD, allowing you to automatically build, test, and validate your application on every push and pull request.

## Overview

When the CI profile is selected, it generates CI/CD configuration files that:

1. **Build your application** using Ant (which handles npm dependencies)
2. **Validate XML files** for well-formedness
3. **Build and run a Docker container** with your application
4. **Run smoke tests** using BATS to verify basic functionality
5. **Run end-to-end tests** using Cypress to test the application in a browser
6. **Capture artifacts** (logs, screenshots) on test failures for debugging

The CI workflows test your application across multiple eXist-db versions (6.4.0, release, latest) and Java versions (11, 21) to ensure compatibility.

## Configuration

The CI profile can be configured in your application's `config.json`:

```json
{
    "ci": {
        "provider": "github",
        "enabled": true
    }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `provider` | string | `"github"` | CI provider to use: `"github"` for GitHub Actions or `"gitlab"` for GitLab CI/CD |
| `enabled` | boolean | `true` | Set to `false` to disable CI configuration generation |

## GitHub Actions

When `provider` is set to `"github"` (default), the profile generates `.github/workflows/ci.yml` with:

- Matrix strategy testing across eXist-db and Java versions
- Automatic Docker image building using Docker Buildx
- Support for private XAR dependencies via BuildKit secrets
- Automatic use of `GITHUB_TOKEN` for accessing private repositories
- Test execution (BATS smoke tests and Cypress e2e tests)
- Artifact upload on failures (logs and screenshots)

## GitLab CI/CD

When `provider` is set to `"gitlab"`, the profile generates `.gitlab-ci.yml` with:

- Parallel jobs for different eXist-db and Java version combinations
- Docker-in-Docker (DinD) support for building and testing containers
- Support for private XAR dependencies via BuildKit secrets
- Automatic use of `CI_JOB_TOKEN` for accessing private repositories
- Test execution (BATS smoke tests and Cypress e2e tests)
- Artifact collection on failures

## Integration with Docker Profile

The CI profile depends on the Docker profile, which means:

- CI workflows build and test using the Dockerfile from the Docker profile
- Tests run against the actual containerized application
- Port configuration from the Docker profile is used in CI workflows
- External XAR dependencies configured in Docker are handled securely in CI

## Automatic Token Support

The CI workflows automatically handle authentication for private XAR packages:

- **GitHub Actions**: Automatically uses `GITHUB_TOKEN` (provided by GitHub Actions) when all private dependencies use `"token": "GITHUB_TOKEN"`
- **GitLab CI**: Automatically uses `CI_JOB_TOKEN` (provided by GitLab CI) when all private dependencies use `"token": "CI_JOB_TOKEN"`
- **Custom tokens**: For other token names, you need to configure them as secrets/variables in your CI platform

## Default Behavior

- All blueprints (docs, serafin, playground, workbench) include CI by default
- CI runs on every push to any branch
- CI runs on pull/merge requests targeting `main` or `master` branches
- Only one provider's files are generated at a time (GitHub Actions OR GitLab CI, not both)

## Requirements

- The CI profile requires the Docker profile (automatically included)
- CI workflows expect BATS tests at `test/*.bats` (provided by Docker profile)
- CI workflows expect Cypress tests at `test/cypress/e2e/**/*.cy.js` (provided by base10 profile)
