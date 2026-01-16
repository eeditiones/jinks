#!/usr/bin/env node

/**
 * Validate dependency consistency between root package.json and config/package.json
 * 
 * Checks:
 * - Shared dependencies have matching versions
 * - All packages in config/package.json exist in npm registry
 * - Custom jinks fields are valid
 */

import fs from 'fs';
import path from 'path';
import https from 'https';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const rootPackageJsonPath = path.join(__dirname, '..', 'package.json');
const configPackageJsonPath = path.join(__dirname, '..', 'config', 'package.json');

/**
 * Find shared dependencies between root and config package.json files
 * @param {Object} rootPackageJson - Root package.json content
 * @param {Object} configPackageJson - Config package.json content
 * @returns {Array<string>} List of package names that exist in both
 */
function findSharedDependencies(rootPackageJson, configPackageJson) {
  const rootDeps = new Set([
    ...Object.keys(rootPackageJson.dependencies || {}),
    ...Object.keys(rootPackageJson.devDependencies || {})
  ]);
  
  const configDeps = new Set([
    ...Object.keys(configPackageJson.dependencies || {}),
    ...Object.keys(configPackageJson.devDependencies || {})
  ]);
  
  // Find intersection: packages that exist in both
  const shared = [];
  for (const dep of rootDeps) {
    if (configDeps.has(dep)) {
      shared.push(dep);
    }
  }
  
  return shared.sort(); // Sort for consistent output
}

function checkNpmPackage(packageName) {
  return new Promise((resolve, reject) => {
    https.get(`https://registry.npmjs.org/${packageName}`, (res) => {
      if (res.statusCode === 404) {
        resolve({ exists: false });
        return;
      }
      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode} for ${packageName}`));
        return;
      }
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const pkg = JSON.parse(data);
          resolve({ exists: true, latest: pkg['dist-tags']?.latest });
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function validateDependencies() {
  const errors = [];
  const warnings = [];

  // Read package.json files
  if (!fs.existsSync(rootPackageJsonPath)) {
    errors.push(`Root package.json not found: ${rootPackageJsonPath}`);
    process.exit(1);
  }

  if (!fs.existsSync(configPackageJsonPath)) {
    errors.push(`Config package.json not found: ${configPackageJsonPath}`);
    process.exit(1);
  }

  const rootPackageJson = JSON.parse(fs.readFileSync(rootPackageJsonPath, 'utf8'));
  const configPackageJson = JSON.parse(fs.readFileSync(configPackageJsonPath, 'utf8'));

  // Dynamically find shared dependencies
  const sharedDeps = findSharedDependencies(rootPackageJson, configPackageJson);
  
  if (sharedDeps.length === 0) {
    console.log('ℹ️  No shared dependencies found between root and config package.json');
  } else {
    console.log(`📦 Found ${sharedDeps.length} shared dependencies to validate: ${sharedDeps.join(', ')}`);
  }

  // Validate shared dependencies match
  console.log('Checking shared dependency versions...');
  sharedDeps.forEach(dep => {
    const rootVersion = rootPackageJson.dependencies?.[dep] || 
                        rootPackageJson.devDependencies?.[dep];
    const configVersion = configPackageJson.dependencies?.[dep] || 
                          configPackageJson.devDependencies?.[dep];
    
    if (rootVersion && configVersion) {
      // Normalize versions (remove ^, ~, etc. for comparison)
      const rootNormalized = rootVersion.replace(/[\^~]/, '');
      const configNormalized = configVersion.replace(/[\^~]/, '');
      
      if (rootNormalized !== configNormalized) {
        errors.push(`Version mismatch for ${dep}: root has ${rootVersion}, config has ${configVersion}`);
      }
    } else if (rootVersion && !configVersion) {
      warnings.push(`${dep} is in root package.json but not in config/package.json`);
    }
  });

  // Validate custom jinks field structure
  console.log('Validating jinks custom fields...');
  if (configPackageJson.jinks) {
    if (configPackageJson.jinks.cdn) {
      for (const [pkg, cdnInfo] of Object.entries(configPackageJson.jinks.cdn)) {
        if (!cdnInfo.base) {
          errors.push(`Invalid CDN config for ${pkg}: missing base`);
        }
        // Check that at least one asset type is defined
        const assetTypes = Object.keys(cdnInfo).filter(key => key !== 'base');
        if (assetTypes.length === 0) {
          errors.push(`Invalid CDN config for ${pkg}: no asset types defined (bundle, css, etc.)`);
        }
        // Validate that all asset type templates contain {{version}} placeholder
        for (const assetType of assetTypes) {
          const template = cdnInfo[assetType];
          if (typeof template === 'string' && !template.includes('{{version}}')) {
            warnings.push(`CDN ${assetType} URL for ${pkg} doesn't contain {{version}} placeholder`);
          }
        }
      }
    }
  }

  // Check all packages exist in npm (async, but we'll do it)
  console.log('Checking packages exist in npm registry...');
  const allDeps = {
    ...(configPackageJson.dependencies || {}),
    ...(configPackageJson.devDependencies || {})
  };

  const npmChecks = [];
  for (const [pkg, version] of Object.entries(allDeps)) {
    npmChecks.push(
      checkNpmPackage(pkg)
        .then(result => {
          if (!result.exists) {
            errors.push(`Package ${pkg} not found in npm registry`);
          }
        })
        .catch(err => {
          warnings.push(`Could not verify ${pkg} in npm registry: ${err.message}`);
        })
    );
  }

  await Promise.all(npmChecks);

  // Report results
  if (errors.length > 0) {
    console.error('\n❌ Validation errors:');
    errors.forEach(e => console.error(`   ${e}`));
  }

  if (warnings.length > 0) {
    console.warn('\n⚠️  Warnings:');
    warnings.forEach(w => console.warn(`   ${w}`));
  }

  if (errors.length === 0 && warnings.length === 0) {
    console.log('\n✅ All validations passed!');
    process.exit(0);
  } else if (errors.length > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

validateDependencies().catch(err => {
  console.error('Validation failed:', err);
  process.exit(1);
});
