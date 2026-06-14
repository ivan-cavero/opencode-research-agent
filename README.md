# OpenCode Research Agent

Elite research agent for OpenCode with free, self-hosted web search via SearXNG.

## Architecture

```
Research Agent (primary)
├── Built-in websearch + webfetch
├── searxng MCP (one-search-mcp) — SearXNG + page extraction
└── omnisearch MCP (mcp-omnisearch) — unified fallback
        │
        ▼
    SearXNG (Docker/Podman) — meta search engine
        │
        ├── Google
        ├── Bing
        ├── DuckDuckGo
        └── Brave
```

**Cost: 0€** — no API keys needed.

## Quick Install

### Windows
```powershell
irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex
```

### Linux
```bash
curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash
```

**What the script does:**
1. Installs **bun** (if not present)
2. Copies the **agent files** to `~/.config/opencode/agents/`
3. **Merges the MCPs** into your existing `~/.config/opencode/opencode.json` — preserves your providers, models, and other MCPs
4. Precaches the MCP packages for faster startup
5. Prints instructions to start SearXNG

## Prerequisites

- **OpenCode** installed
- **Docker** or **Podman** (to run SearXNG)

## Start SearXNG

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
# or
podman run -d --name searxng -p 8080:8080 searxng/searxng
```

Verify with `curl http://localhost:8080`.

## Restart OpenCode

Close and reopen OpenCode. The **Research** agent appears as a primary tab (TAB to switch).

## Usage Examples

| Intent | Example |
|--------|---------|
| Explanatory | `what is PagedAttention and how does it work?` |
| Problem-solving | `I want to build an AI inference server for my RTX Pro 6000` |
| Comparison | `compare vLLM vs SGLang vs llama.cpp for local inference` |
| Deep dive | `@deep-research best RAG architecture for 5M documents` |

## Files

| File | Purpose |
|------|---------|
| `opencode.json` | MCP fragment (merged into your existing config by the installer) |
| `agents/research.md` | Research agent prompt |
| `agents/deep-research.md` | Deep research subagent (`@deep-research`) |