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

- **`cdn`**: CDN URL templates for packages loaded from CDN. The `{{version}}` placeholder is replaced with the actual version from dependencies (or override if present). Each package can define multiple asset types (e.g., `bundle`, `css`). The CDN map keys are constructed as `{package-name}-{asset-type}`.
- **`overrides`**: Profile-specific version overrides. When a profile needs a different version than the default, add it here. The generator checks active profiles in order and uses the first matching override. Example:
  ```json
  "overrides": {
    "legacy-forms": {
      "@jinntec/fore": "^2.0.0"
    },
    "static": {
      "@jinntec/fore": "^2.0.0"
    }
  }
  ```
  If multiple profiles have overrides for the same package, the first profile in the active profiles list takes precedence.

## How It Works

### 1. Dependency Loading

When jinks generates an application:

1. `modules/generator.xql` loads `config/package.json`
2. CDN URLs are pre-computed using `config:cdn-url()` function
3. Dependencies and CDN URLs are added to the template context as `$dependencies` and `$cdn`

### 2. Template Usage

Templates access dependencies via the context. CDN map keys are constructed as `{package-name}-{asset-type}` (e.g., `@teipublisher/pb-components-bundle`, `fore-bundle`, `swagger-ui-css`).

**Important**: For map keys containing special characters (like `@`), use function call syntax: `$cdn?('key')` instead of `$cdn?key`.

```html
<!-- Use CDN URL from dependencies -->
[% if exists($cdn?fore-bundle) %]
<script type="module" src="[[ $cdn?fore-bundle ]]"></script>
[% elif exists($cdn?('@teipublisher/pb-components-bundle')) %]
<script type="module" src="[[ $cdn?('@teipublisher/pb-components-bundle') ]]"></script>
[% else %]
<!-- Fallback to hardcoded URL -->
<script type="module" src="https://cdn.jsdelivr.net/npm/@jinntec/fore@2.0.0/dist/fore.js"></script>
[% endif %]
```

**Styles Array Processing**: The `styles` array in profile `config.json` files is automatically processed to replace hardcoded CDN URLs with templated versions from `config/package.json`.

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
           "bundle": "@{{version}}/dist/bundle.js",
           "css": "@{{version}}/dist/styles.css"
         }
       }
     }
   }
   ```

3. Update templates to use the CDN map. The key format is `{package-name}-{asset-type}`:
   ```html
   [% if exists($cdn?new-package-bundle) %]
   <script type="module" src="[[ $cdn?new-package-bundle ]]"></script>
   [% endif %]
   ```
   
   For packages with special characters (like `@`), use function call syntax:
   ```html
   [% if exists($cdn?('@scope/package-bundle')) %]
   <script type="module" src="[[ $cdn?('@scope/package-bundle') ]]"></script>
   [% endif %]
   ```

4. The CDN map is automatically built by `modules/generator.xql` from the `jinks.cdn` configuration.

### Updating Versions

- **Manual**: Edit `config/package.json` directly
- **Automated**: Dependabot will create PRs for updates
- **Shared deps**: Run `npm run sync:dependencies` to sync from root `package.json`

### Profile-Specific Overrides

If a profile needs a different version than the default:

1. Add override to `config/package.json`:
   ```json
   {
     "jinks": {
       "overrides": {
         "profile-name": {
           "package-name": "^different-version"
         }
       }
     }
   }
   ```

2. The generator automatically applies overrides when building CDN URLs and generating `package.json`

3. Overrides are checked in profile order - first matching override wins

4. When Dependabot updates the base version, overrides are preserved (profiles continue using their specified versions)

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

Both scripts automatically detect shared dependencies by comparing the root and config `package.json` files.

## Files

- **`config/package.json`**: Dependency registry with versions and CDN templates
- **`config/package-lock.json`**: Lock file required by Dependabot (generated with `npm install --package-lock-only`)
- **`scripts/sync-dependencies.js`**: Script to sync shared dependencies
- **`scripts/validate-dependencies.js`**: Script to validate dependencies
- **`.github/dependabot.yml`**: Dependabot configuration for automated updates
- **`.github/workflows/sync-dependencies.yml`**: GitHub Action to auto-sync on PRs

## Creating/Updating package-lock.json

The `package-lock.json` file is required for Dependabot to work. To create or update it without installing `node_modules`:

```bash
cd config/
npm install --package-lock-only
```

This generates the lock file based on `package.json` without creating a `node_modules` directory, which is ideal since `config/` dependencies are only used for version tracking, not for local installation.

## Integration Points

1. **Template System** (`modules/generator.xql`): 
   - Loads `config/package.json` and makes it available as `$dependencies`
   - Dynamically builds `$cdn` map from `jinks.cdn` configuration
   - Processes `styles` arrays to replace hardcoded CDN URLs with templated versions
   - Auto-populates profile-specific dependencies (e.g., `jinntap` version from `config/package.json`)

2. **API Pages** (`modules/api.xql`): Adds dependencies and CDN URLs to context for jinks UI pages

3. **Templates**: Use `$cdn` map for CDN URLs instead of hardcoded versions
   - Simple keys: `$cdn?fore-bundle`
   - Keys with special characters: `$cdn?('@teipublisher/pb-components-bundle')`

4. **Generated Config** (`profiles/base10/modules/generated-config.tpl.xql`): Derives `$config:webcomponents` from `$dependencies` when available

## Benefits

- **Single Source of Truth**: All dependency versions in one place
- **Automated Updates**: Dependabot handles version bumps
- **Consistency**: All generated apps use the same dependency versions
- **Maintainability**: Easy to update versions across all apps
- **CDN Management**: Centralized CDN URL templates with version placeholders
