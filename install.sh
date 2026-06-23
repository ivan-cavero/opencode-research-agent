#!/usr/bin/env bash
# OpenCode Research Agent Installer — Bootstrap
# Requires Node.js. Downloads and runs the cross-platform Node.js installer.
# Usage: curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash

set -e

INSTALLER_URL="https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs"

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "  Node.js is required. Install it: https://nodejs.org"
    exit 1
fi

# Download installer to temp file
TMP=$(mktemp)
trap "rm -f $TMP" EXIT

curl -fsSL "$INSTALLER_URL" -o "$TMP"
node "$TMP"
