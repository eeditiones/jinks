# Generated App Dependencies Registry

This directory contains the dependency registry for all generated TEI Publisher applications created by jinks.

## Purpose

The `package.json` file in this directory serves as the **single source of truth** for all dependencies used by generated applications. This ensures:

- ✅ Consistent dependency versions across all generated apps
- ✅ Automated dependency updates via Dependabot
- ✅ Centralized management of CDN URLs
- ✅ Version synchronization with jinks' own dependencies

## Structure

### `package.json`

Standard npm `package.json` format with two custom fields:

#### Standard Fields

- **`dependencies`**: Production dependencies for generated apps
- **`devDependencies`**: Development dependencies (testing, validation, etc.)

#### Custom `jinks` Field

The `jinks` field contains metadata specific to jinks templating:

```json
{
  "jinks": {
    "cdn": {
      "@jinntec/fore": {
        "base": "https://cdn.jsdelivr.net/npm/@jinntec/fore",
        "bundle": "@{{version}}/dist/fore.js",
        "css": "@{{version}}/resources/fore.css"
      }
    },
    "overrides": {
      "base10": {
        "@jinntec/fore": "^2.8.0"
      }
    }
  }
}
```

- **`cdn`**: CDN URL templates for packages loaded from CDN. The `{{version}}` placeholder is replaced with the actual version from dependencies.
- **`overrides`**: Profile-specific version overrides (optional, for future use)

## How It Works

### 1. Dependency Loading

When jinks generates an application:

1. `modules/generator.xql` loads `config/package.json`
2. CDN URLs are pre-computed using `config:cdn-url()` function
3. Dependencies and CDN URLs are added to the template context as `$dependencies` and `$cdn`

### 2. Template Usage

Templates access dependencies via the context:

```html
<!-- Use CDN URL from dependencies -->
[% if exists($cdn?fore-bundle) %]
<script type="module" src="[[ $cdn?fore-bundle ]]"></script>
[% else %]
<!-- Fallback to hardcoded URL -->
<script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/fore@2.0.0/dist/fore.js"></script>
[% endif %]
```

### 3. Version Synchronization

Shared dependencies (used by both jinks and generated apps) are automatically synced:

- **Sync Script**: `scripts/sync-dependencies.js` finds shared dependencies and syncs versions from root `package.json` to `config/package.json`
- **GitHub Action**: `.github/workflows/sync-dependencies.yml` runs the sync script when root `package.json` changes
- **Dependabot**: Monitors both root and `config/package.json` for updates

### 4. Automated Updates

- **Dependabot** creates PRs for dependency updates in `config/package.json`
- When a PR updates `config/package.json`, the new versions are automatically used in generated apps
- CDN URLs in templates automatically use the updated versions

## Managing Dependencies

### Adding a New Dependency

1. Add the package to `config/package.json`:
   ```json
   {
     "dependencies": {
       "new-package": "^1.0.0"
     }
   }
   ```

2. If it's loaded from CDN, add CDN URL template:
   ```json
   {
     "jinks": {
       "cdn": {
         "new-package": {
           "base": "https://cdn.jsdelivr.net/npm/new-package",
           "bundle": "@{{version}}/dist/bundle.js"
         }
       }
     }
   }
   ```

3. Update templates to use `$cdn?new-package-bundle` (or compute it in `modules/generator.xql`)

### Updating Versions

- **Manual**: Edit `config/package.json` directly
- **Automated**: Dependabot will create PRs for updates
- **Shared deps**: Run `npm run sync:dependencies` to sync from root `package.json`

### Validating Dependencies

Run the validation script to check for issues:

```bash
npm run validate:dependencies
```

This checks:
- Shared dependencies match between root and config
- All packages exist in npm registry
- CDN URL templates are valid

## Scripts

- **`npm run sync:dependencies`**: Sync shared dependencies from root `package.json` to `config/package.json`
- **`npm run validate:dependencies`**: Validate dependency consistency and npm registry existence

## Files

- **`config/package.json`**: Dependency registry with versions and CDN templates
- **`scripts/sync-dependencies.js`**: Script to sync shared dependencies
- **`scripts/validate-dependencies.js`**: Script to validate dependencies
- **`.github/dependabot.yml`**: Dependabot configuration for automated updates
- **`.github/workflows/sync-dependencies.yml`**: GitHub Action to auto-sync on PRs

## Integration Points

1. **Template System** (`modules/generator.xql`): Loads dependencies and computes CDN URLs
2. **API Pages** (`modules/api.xql`): Adds dependencies to context for jinks UI pages
3. **Templates**: Use `$cdn` map for CDN URLs instead of hardcoded versions

## Benefits

- **Single Source of Truth**: All dependency versions in one place
- **Automated Updates**: Dependabot handles version bumps
- **Consistency**: All generated apps use the same dependency versions
- **Maintainability**: Easy to update versions across all apps
- **CDN Management**: Centralized CDN URL templates with version placeholders
