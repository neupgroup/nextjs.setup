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
const baseFile = path.join(projectDir, '@base/application.json');
const envFile = path.join(projectDir, '.env');

try {
  const base = JSON.parse(fs.readFileSync(baseFile, 'utf8'));
  const values = {
    NEUP_APP_ID: base.identity?.applicationId,
    NEUP_APP_SECRET: '',
    NEXT_PUBLIC_APP_BASEPATH: base.platforms?.web?.basepath,
    APP_ASSETS_LOGO_MAIN: base.assets?.logo?.main,
    APP_ASSETS_FAVICON: base.assets?.favicon?.path ?? base.assets?.favicon,
  };
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
  console.error(`Unable to generate ${envFile} from ${baseFile}: ${error.message}`);
  process.exitCode = 1;
}
NODE
