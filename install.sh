#!/usr/bin/env bash
set -e

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cd "$TMP"
npm init -y >/dev/null 2>&1
npm install @clack/prompts kleur >/dev/null 2>&1

curl -fsSL "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -o "$TMP/install.mjs"

# If /dev/tty exists (real terminal), redirect stdin to it so @clack/prompts
# can read keyboard input even when piped from curl.
if [ -e /dev/tty ]; then
    exec < /dev/tty
fi

node "$TMP/install.mjs"
