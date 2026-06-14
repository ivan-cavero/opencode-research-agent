#!/usr/bin/env bash
# Research Agent for OpenCode — Linux Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash

set -e

REPO="ivan-cavero/opencode-research-agent"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
CONFIG_DIR="$HOME/.config/opencode"
AGENTS_DIR="$CONFIG_DIR/agents"

echo "=== OpenCode Research Agent Installer ==="
echo ""

# 1. Install bun if missing
if ! command -v bun &>/dev/null; then
    echo "[1/4] Installing bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
else
    echo "[1/4] bun already installed"
fi

# 2. Download agent files
echo "[2/4] Creating agent files..."
mkdir -p "$AGENTS_DIR"
curl -fsSL "$RAW/agents/research.md" -o "$AGENTS_DIR/research.md"
curl -fsSL "$RAW/agents/deep-research.md" -o "$AGENTS_DIR/deep-research.md"
curl -fsSL "$RAW/agents/verifier.md" -o "$AGENTS_DIR/verifier.md"

# 3. Merge MCPs into existing opencode.json (preserves user config)
echo "[3/4] Adding MCPs to your existing config..."
CONFIG_FILE="$CONFIG_DIR/opencode.json"
FRAGMENT_FILE=$(mktemp)
curl -fsSL "$RAW/opencode.json" -o "$FRAGMENT_FILE"

if [ -f "$CONFIG_FILE" ]; then
    jq -s '.[0] as $existing | .[1] as $fragment |
      if $existing.mcp then $existing else $existing + {mcp: {}} end |
      .mcp = (.mcp + $fragment.mcp) |
      if .default_agent == null then .default_agent = "research" else . end
    ' "$CONFIG_FILE" "$FRAGMENT_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "  > Existing config preserved. MCPs added: searxng, omnisearch, arxiv"
else
    jq '. + {"$schema": "https://opencode.ai/config.json", "default_agent": "research"}' "$FRAGMENT_FILE" > "$CONFIG_FILE"
fi
rm "$FRAGMENT_FILE"

# 4. Cache MCP packages
echo "[4/4] Caching MCP packages..."
bunx -y -p one-search-mcp one-search-mcp --version 2>/dev/null || true
bunx -y -p mcp-omnisearch mcp-omnisearch --version 2>/dev/null || true
bunx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>/dev/null || true

echo ""
echo "=== Installation complete! ==="
echo ""
echo "IMPORTANT: Start SearXNG before using the research agent:"
echo "  docker run -d --name searxng -p 8080:8080 searxng/searxng"
echo "  (or: podman run -d --name searxng -p 8080:8080 searxng/searxng)"
echo ""
echo "Then restart OpenCode. The Research agent will appear as a tab."