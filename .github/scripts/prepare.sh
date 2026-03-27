#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/webpro-nl/knip"
BRANCH="main"
REPO_DIR="source-repo"
DOCUSAURUS_PATH="packages/knip/fixtures/plugins/docusaurus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# --- Node version ---
# Node 22 has a require.resolveWeak incompatibility with Docusaurus webpack SSR
# Use Node 20 (LTS) which is fully supported by Docusaurus 3.x
export NVM_DIR="${HOME}/.nvm"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm install 20 --no-progress
    nvm use 20
fi
echo "[INFO] Using Node $(node --version)"

# --- Move into the fixture directory ---
# The Docusaurus site is a knip fixture at packages/knip/fixtures/plugins/docusaurus
# The pnpm-workspace.yaml excludes packages/knip/fixtures, so npm works here without
# workspace interference.
cd "$REPO_DIR/$DOCUSAURUS_PATH"
echo "[INFO] Working directory: $(pwd)"

# --- Fix package.json - remove non-existent packages ---
# The fixture has fake packages (@my-company/*, docusaurus-plugin-awesome) for knip testing.
# Replace package.json with only real Docusaurus packages.
cat > package.json << 'PKGJSON'
{
  "name": "@plugins/docusaurus",
  "type": "module",
  "scripts": {
    "docusaurus": "docusaurus",
    "write-translations": "docusaurus write-translations",
    "build": "docusaurus build"
  },
  "dependencies": {
    "@docusaurus/core": "3.7.0",
    "@docusaurus/preset-classic": "3.7.0",
    "@mdx-js/react": "^3.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
PKGJSON

# --- Fix docusaurus.config.js - remove fake plugins ---
# Remove the .ts config so Docusaurus only loads the .js one (both exist in the fixture)
rm -f docusaurus.config.ts sidebars.ts
# The original config references fake plugins (for knip fixture testing).
# Simplify to only use real Docusaurus packages.
cat > docusaurus.config.js << 'DOCCONFIG'
export default {
  title: 'Docusaurus',
  url: 'https://docusaurus.io',
  baseUrl: '/',
  presets: [
    ['@docusaurus/preset-classic', { debug: false }],
  ],
  future: {
    // Use hash router to skip SSR/SSG phase entirely.
    // The SSG eval context can't resolve webpack aliases (@theme/*, @site/*, @generated/*).
    experimental_router: 'hash',
  },
};
DOCCONFIG

# --- Fix empty HomepageFeatures component ---
# The component file is intentionally empty (for knip testing), but Docusaurus needs a default export.
mkdir -p src/components/HomepageFeatures
cat > src/components/HomepageFeatures/index.js << 'FEATURES'
export default function HomepageFeatures() {
  return null;
}
FEATURES

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Install dependencies with npm ---
# Use npm (not pnpm) to avoid workspace interference
npm install

# --- Patch Docusaurus SSR require to fix webpack SSR issues ---
# Docusaurus 3.x ssgNodeRequire.js issues in the SSR eval context:
# 1. require.resolveWeak missing (webpack lazy loading) — must return undefined
# 2. Some externally-required modules are ESM files that import CSS/@theme/* —
#    these can't resolve in Node.js outside webpack. Wrap require in try-catch.
node -e "
const fs = require('fs');
const path = 'node_modules/@docusaurus/core/lib/ssg/ssgNodeRequire.js';
let content = fs.readFileSync(path, 'utf8');
if (!content.includes('resolveWeak')) {
    content = content.replace(
        'const ssgRequireFunction = (id) => {\n        const module = realRequire(id);\n        allRequiredIds.push(id);\n        return module;\n    };',
        'const ssgRequireFunction = (id) => {\n        try {\n            const module = realRequire(id);\n            allRequiredIds.push(id);\n            return module;\n        } catch (e) {\n            if (e.code === \"ERR_MODULE_NOT_FOUND\" || e.code === \"ERR_UNKNOWN_FILE_EXTENSION\") {\n                return {};\n            }\n            throw e;\n        }\n    };'
    );
    content = content.replace(
        'ssgRequireFunction.main = realRequire.main;',
        'ssgRequireFunction.main = realRequire.main;\n    ssgRequireFunction.resolveWeak = () => undefined;\n    realRequire.extensions[\".css\"] = (m) => { m.exports = {}; };\n    realRequire.extensions[\".scss\"] = (m) => { m.exports = {}; };'
    );
    fs.writeFileSync(path, content);
    console.log('[INFO] ssgNodeRequire patched');
} else {
    console.log('[INFO] ssgNodeRequire already patched');
}
"

echo "[DONE] Repository is ready for docusaurus commands."
