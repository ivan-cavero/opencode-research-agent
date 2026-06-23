#!/usr/bin/env bash
# OpenCode Research Agent Installer — Bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash

set -e

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo ""
echo "  OpenCode Research Agent Installer"
echo ""

# Step 1: Install deps
echo "  [1/3] Installing dependencies..."
cd "$TMP"
npm init -y 2>/dev/null
npm install @clack/prompts kleur 2>&1 | tail -1
echo "  ✓ Dependencies ready"

# Step 2: Download installer
echo "  [2/3] Downloading installer..."
curl -fsSL "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -o "$TMP/install.mjs"
echo "  ✓ Installer downloaded"

# Step 3: Run with TTY input (if available)
echo "  [3/3] Starting installer..."
echo ""

# If /dev/tty exists, redirect stdin so @clack/prompts can read keyboard
if [ -e /dev/tty ] && [ -r /dev/tty ]; then
    exec < /dev/tty 2>/dev/null || true
fi

node "$TMP/install.mjs"
