#!/usr/bin/env bash

set -Eeuo pipefail

# Located at .neup/setup/generation/env.sh in the guidelines checkout.
# An optional argument selects the application root for standalone use.
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${1:-$SCRIPT_DIR/../../..}"

node - "$PROJECT_DIR" <<'NODE'
const fs = require('fs');
const path = require('path');
const projectDir = process.argv[2];
const baseDir = path.join(projectDir, '@base');
const applicationFile = path.join(baseDir, 'application.json');
const identityFile = path.join(baseDir, 'identity.json');
const assetsFile = path.join(baseDir, 'assets.json');
const modulesFile = path.join(baseDir, 'modules.json');
const envFile = path.join(projectDir, '.env');

try {
  const readJson = (file, fallback) => fs.existsSync(file)
    ? JSON.parse(fs.readFileSync(file, 'utf8'))
    : fallback;
  const application = readJson(applicationFile, {});
  const identity = readJson(identityFile, {});
  const assets = readJson(assetsFile, {});
  const modules = readJson(modulesFile, []);
  const values = {
    NEUP_APP_ID: application.applicationId ?? application.projectId ?? identity.applicationId ?? application.id ?? identity.id,
    NEUP_APP_SECRET: '',
    NEXT_PUBLIC_APP_BASEPATH: application.basepath,
    APP_ASSETS_LOGO_MAIN: assets.logo?.main,
    APP_ASSETS_FAVICON: assets.favicon?.path ?? assets.favicon,
  };
  for (const module of (Array.isArray(modules) ? modules : [])) {
    if (!module?.isRequired || typeof module.name !== 'string' || !module.projectId) continue;
    const key = `NEUP_${module.name.replace(/^neup\\./, '').replace(/[^a-z0-9]+/gi, '_').toUpperCase()}_PROJECT_ID`;
    values[key] = module.projectId;
  }
  const existing = fs.existsSync(envFile) ? fs.readFileSync(envFile, 'utf8') : '';
  const additions = [];
  for (const [key, value] of Object.entries(values)) {
    if (new RegExp(`^\\s*(?:export\\s+)?${key}\\s*=`, 'm').test(existing)) continue;
    additions.push([key, `${key}=${JSON.stringify(value == null ? '' : String(value))}`]);
  }
  if (additions.length) {
    const separator = existing && !existing.endsWith('\n') ? '\n' : '';
    fs.appendFileSync(envFile, separator + additions.map(([, line]) => line).join('\n') + '\n');
    for (const [key] of additions) console.log(`Added ${key} to .env.`);
  }
} catch (error) {
  console.error(`Unable to generate environment from ${baseDir}: ${error.message}`);
  process.exitCode = 1;
}
NODE
