#!/usr/bin/env bash
set -e

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

echo ""
echo "  OpenCode Research Agent Installer"
echo ""

echo "  [1/3] Installing dependencies..." >&2
cd "$TMP"
npm init -y >/dev/null 2>&1
npm install @clack/prompts kleur >/dev/null 2>&1
echo "  ✓ Dependencies ready" >&2

echo "  [2/3] Downloading installer..." >&2
curl -fsSL "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -o "$TMP/install.mjs" >/dev/null 2>&1
echo "  ✓ Installer downloaded" >&2

echo "  [3/3] Starting installer..." >&2
echo "" >&2

# Redirect stdin to TTY so @clack/prompts can read keyboard input
if [ -e /dev/tty ] && [ -r /dev/tty ]; then
    exec < /dev/tty 2>/dev/null || true
fi

node "$TMP/install.mjs"
