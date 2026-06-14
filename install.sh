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

# 2. Create config directories
echo "[2/4] Creating config directories..."
mkdir -p "$AGENTS_DIR"

# 3. Download config files
echo "[3/4] Downloading agent files..."
curl -fsSL "$RAW/opencode.json" -o "$CONFIG_DIR/opencode.json"
curl -fsSL "$RAW/agents/research.md" -o "$AGENTS_DIR/research.md"
curl -fsSL "$RAW/agents/deep-research.md" -o "$AGENTS_DIR/deep-research.md"

# 4. Cache MCP packages
echo "[4/4] Caching MCP packages (first run is faster after this)..."
bunx -y -p one-search-mcp one-search-mcp --version 2>/dev/null || true
bunx -y -p mcp-omnisearch mcp-omnisearch --version 2>/dev/null || true

echo ""
echo "=== Installation complete! ==="
echo ""
echo "IMPORTANT: Start SearXNG before using the research agent:"
echo "  docker run -d --name searxng -p 8080:8080 searxng/searxng"
echo "  (or: podman run -d --name searxng -p 8080:8080 searxng/searxng)"
echo ""
echo "Then restart OpenCode. The Research agent will appear as a tab."