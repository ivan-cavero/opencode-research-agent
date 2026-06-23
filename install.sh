#!/usr/bin/env bash
set -e

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo ""
echo "  OpenCode Research Agent Installer"
echo ""

echo "  [1/3] Installing dependencies..."
cd "$TMP"
npm init -y >/dev/null 2>&1
npm install @clack/prompts kleur >/dev/null 2>&1
echo "  ✓ Dependencies ready"

echo "  [2/3] Downloading installer..."
curl -fsSL "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -o "$TMP/install.mjs"
echo "  ✓ Installer downloaded"

echo "  [3/3] Starting installer..."
echo ""

# Run node with stdin from /dev/tty (so @clack/prompts works with arrow keys)
if [ -e /dev/tty ]; then
    node "$TMP/install.mjs" < /dev/tty
else
    node "$TMP/install.mjs"
fi
