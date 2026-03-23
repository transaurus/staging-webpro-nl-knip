#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/webpro-nl/knip"
REPO_DIR="source-repo"
DOCUSAURUS_PATH="packages/knip/fixtures/plugins/docusaurus"
WORK_DIR="/tmp/knip-docusaurus-fixture"

echo "=== Step 1: Set up Node.js 20 ==="
# Node 22 has a require.resolveWeak incompatibility with Docusaurus webpack SSR
# Use Node 20 (LTS) which is fully supported by Docusaurus 3.x
export NVM_DIR="${HOME}/.nvm"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    nvm install 20 --no-progress
    nvm use 20
else
    echo "NVM not found, using system node"
fi
node --version
npm --version

echo "=== Step 2: Clone repository ==="
git clone --depth=1 "$REPO_URL" "$REPO_DIR"

echo "=== Step 3: Copy fixture to temp dir (outside pnpm workspace) ==="
# The pnpm-workspace.yaml excludes packages/knip/fixtures, so we copy to /tmp
# to avoid pnpm workspace interference
rm -rf "$WORK_DIR"
cp -r "$REPO_DIR/$DOCUSAURUS_PATH" "$WORK_DIR"
cd "$WORK_DIR"
echo "Working directory: $(pwd)"

echo "=== Step 4: Fix package.json - remove non-existent packages ==="
# The fixture has fake packages (@my-company/*, docusaurus-plugin-awesome) for knip testing
# These don't exist on npm, so we replace package.json with only real Docusaurus packages
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

echo "=== Step 5: Fix docusaurus.config.js - remove fake plugins ==="
# Remove the .ts config so Docusaurus only loads the .js one (both exist in the fixture)
rm -f docusaurus.config.ts sidebars.ts
# The original config references fake plugins (for knip fixture testing)
# We simplify it to only use real Docusaurus packages
cat > docusaurus.config.js << 'DOCDONFIG'
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
    // Hash router builds a SPA entry point instead of server-rendering individual pages.
    experimental_router: 'hash',
  },
};
DOCDONFIG

echo "=== Step 6: Fix empty HomepageFeatures component (it's a knip fixture placeholder) ==="
# The component file is intentionally empty (for knip testing), but Docusaurus build needs a default export
mkdir -p src/components/HomepageFeatures
cat > src/components/HomepageFeatures/index.js << 'FEATURES'
export default function HomepageFeatures() {
  return null;
}
FEATURES

echo "=== Step 7: Install dependencies with npm ==="
# Use npm (not pnpm) to avoid workspace interference
npm install

echo "=== Step 8: Patch Docusaurus SSR require to fix webpack SSR issues ==="
# Docusaurus 3.x ssgNodeRequire.js issues in the SSR eval context:
# 1. require.resolveWeak missing (webpack lazy loading) — must return undefined
# 2. Some externally-required modules are ESM files that import CSS/@theme/* —
#    these can't resolve in Node.js outside webpack. Wrap require in try-catch
#    to return empty stubs for unresolvable modules.

node -e "
const fs = require('fs');
const path = 'node_modules/@docusaurus/core/lib/ssg/ssgNodeRequire.js';
let content = fs.readFileSync(path, 'utf8');
if (!content.includes('resolveWeak')) {
    // Add resolveWeak stub and error-tolerant require wrapper
    content = content.replace(
        'const ssgRequireFunction = (id) => {\n        const module = realRequire(id);\n        allRequiredIds.push(id);\n        return module;\n    };',
        'const ssgRequireFunction = (id) => {\n        try {\n            const module = realRequire(id);\n            allRequiredIds.push(id);\n            return module;\n        } catch (e) {\n            if (e.code === \"ERR_MODULE_NOT_FOUND\" || e.code === \"ERR_UNKNOWN_FILE_EXTENSION\") {\n                return {};\n            }\n            throw e;\n        }\n    };'
    );
    content = content.replace(
        'ssgRequireFunction.main = realRequire.main;',
        'ssgRequireFunction.main = realRequire.main;\n    ssgRequireFunction.resolveWeak = () => undefined;\n    realRequire.extensions[\".css\"] = (m) => { m.exports = {}; };\n    realRequire.extensions[\".scss\"] = (m) => { m.exports = {}; };'
    );
    fs.writeFileSync(path, content);
    console.log('ssgNodeRequire patched');
} else {
    console.log('ssgNodeRequire already patched');
}
"

echo "=== Step 9: Run write-translations ==="
npx docusaurus write-translations

echo "=== Step 10: Build Docusaurus site ==="
npm run build

echo "=== Step 11: Verify build output ==="
if [ -d "build" ] && [ "$(ls -A build)" ]; then
    echo "Build directory exists and contains files:"
    ls build/ | head -20
else
    echo "ERROR: build/ directory is missing or empty"
    exit 1
fi

echo "=== SUCCESS ==="
echo "Generated i18n files:"
find i18n -name "*.json" 2>/dev/null | head -30 || echo "No i18n directory found"
echo "Build output files: $(find build -type f | wc -l)"

echo "Copying i18n output back to source repo..."
cp -r i18n "$OLDPWD/$REPO_DIR/$DOCUSAURUS_PATH/" 2>/dev/null || true
