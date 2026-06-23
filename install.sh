#!/usr/bin/env bash
set -e
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
cd "$TMP"
npm init -y >/dev/null 2>&1
npm install @clack/prompts kleur >/dev/null 2>&1
curl -fsSL "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -o install.mjs
exec node install.mjs < /dev/tty
