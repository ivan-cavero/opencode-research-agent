#!/usr/bin/env bash
# OpenCode Research Agent Installer — Bootstrap
# Downloads and runs the cross-platform Node.js installer.
# Uses Bun if available, falls back to Node.
# Usage: curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash

set -e

URL="https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs"

# Detect runtime: prefer Bun, fallback to Node
if command -v bun &>/dev/null; then
    RUNTIME="bun"
elif command -v node &>/dev/null; then
    RUNTIME="node"
else
    echo "  Node.js or Bun required. Install: https://nodejs.org or https://bun.sh"
    exit 1
fi

# Download to temp file with .mjs extension (needed for Node ESM detection)
TMP="/tmp/opencode-installer-$$.mjs"
trap "rm -f $TMP" EXIT

if command -v curl &>/dev/null; then
    curl -fsSL "$URL" -o "$TMP"
elif command -v wget &>/dev/null; then
    wget -q "$URL" -O "$TMP"
else
    echo "  curl or wget required"
    exit 1
fi

$RUNTIME "$TMP"
