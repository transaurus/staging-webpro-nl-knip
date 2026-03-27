#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for webpro/nl-knip (Docusaurus fixture)
# Runs on existing source tree (no clone). Installs deps, runs pre-build steps, builds.
# The working directory should be the docusaurus fixture root (containing package.json,
# docusaurus.config.js, etc. — already simplified by prepare.sh).

# --- Node version ---
# Node 22 has a require.resolveWeak incompatibility with Docusaurus webpack SSR
export NVM_DIR="${HOME}/.nvm"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    source "$NVM_DIR/nvm.sh"
    nvm install 20 --no-progress
    nvm use 20
fi
echo "[INFO] Using Node $(node --version)"

# --- Install dependencies with npm ---
npm install

# --- Patch Docusaurus SSR require to fix webpack SSR issues ---
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

# --- Build ---
npm run build

echo "[DONE] Build complete."
