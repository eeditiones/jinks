#!/usr/bin/env node

/**
 * Sync shared dependencies from root package.json to config/package.json
 * 
 * This script ensures that dependencies used by both jinks and generated apps
 * stay in sync between the root package.json and config/package.json
 */

import fs from 'fs';
import path from 'path';
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

function syncDependencies() {
  if (!fs.existsSync(rootPackageJsonPath)) {
    console.error(`❌ Root package.json not found: ${rootPackageJsonPath}`);
    process.exit(1);
  }

  if (!fs.existsSync(configPackageJsonPath)) {
    console.error(`❌ Config package.json not found: ${configPackageJsonPath}`);
    console.error('   Run this script after creating config/package.json');
    process.exit(1);
  }

  const rootPackageJson = JSON.parse(fs.readFileSync(rootPackageJsonPath, 'utf8'));
  const configPackageJson = JSON.parse(fs.readFileSync(configPackageJsonPath, 'utf8'));
  
  // Dynamically find shared dependencies
  const sharedDeps = findSharedDependencies(rootPackageJson, configPackageJson);
  
  if (sharedDeps.length === 0) {
    console.log('ℹ️  No shared dependencies found between root and config package.json');
    return;
  }
  
  console.log(`📦 Found ${sharedDeps.length} shared dependencies: ${sharedDeps.join(', ')}`);

  // Ensure dependencies and devDependencies exist
  if (!configPackageJson.dependencies) {
    configPackageJson.dependencies = {};
  }
  if (!configPackageJson.devDependencies) {
    configPackageJson.devDependencies = {};
  }

  // Sync shared dependencies from root package.json to config/package.json
  let updated = false;
  const updates = [];

  sharedDeps.forEach(dep => {
    const version = rootPackageJson.dependencies?.[dep] || 
                    rootPackageJson.devDependencies?.[dep];
    
    if (version) {
      const isDevDep = rootPackageJson.devDependencies?.[dep];
      
      // Remove from opposite category if present
      if (isDevDep && configPackageJson.dependencies[dep]) {
        delete configPackageJson.dependencies[dep];
        updated = true;
      } else if (!isDevDep && configPackageJson.devDependencies[dep]) {
        delete configPackageJson.devDependencies[dep];
        updated = true;
      }
      
      // Update in correct category
      const target = isDevDep ? configPackageJson.devDependencies : configPackageJson.dependencies;
      if (target[dep] !== version) {
        target[dep] = version;
        updated = true;
        updates.push(`${dep}: ${target[dep] || 'added'} → ${version}`);
      }
    }
  });

  if (updated) {
    // Sort dependencies for consistent output
    if (configPackageJson.dependencies) {
      configPackageJson.dependencies = Object.fromEntries(
        Object.entries(configPackageJson.dependencies).sort()
      );
    }
    if (configPackageJson.devDependencies) {
      configPackageJson.devDependencies = Object.fromEntries(
        Object.entries(configPackageJson.devDependencies).sort()
      );
    }

    fs.writeFileSync(
      configPackageJsonPath,
      JSON.stringify(configPackageJson, null, 2) + '\n'
    );
    console.log('✅ Synced shared dependencies from root package.json to config/package.json');
    console.log('   Updates:');
    updates.forEach(u => console.log(`   - ${u}`));
  } else {
    console.log('✅ All shared dependencies already in sync');
  }
}

syncDependencies();
