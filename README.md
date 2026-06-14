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

**Cost: 0€** — no API keys needed. SearXNG searches multiple engines for free.

## Quick Install

### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex
```

### Linux (bash)
```bash
curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash
```

## Prerequisites

- **OpenCode** installed
- **Docker** or **Podman** (to run SearXNG)

## Start SearXNG

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
# or
podman run -d --name searxng -p 8080:8080 searxng/searxng
```

Verify: `curl http://localhost:8080` should return SearXNG HTML.

## Restart OpenCode

Close and reopen OpenCode. The **Research** agent will appear as a primary tab (alongside Build and Plan). Press TAB to switch.

## Usage Examples

### Explanatory
```
what is PagedAttention and how does it work?
```

### Problem-solving
```
I want to build an AI inference server for my RTX Pro 6000
```

### Comparison
```
compare vLLM vs SGLang vs llama.cpp for local inference
```

### Deep dive
```
@deep-research what is the best RAG architecture for a 5M document enterprise system?
```

## Files

| File | Purpose |
|------|---------|
| `opencode.json` | OpenCode config with MCPs |
| `agents/research.md` | Research agent prompt |
| `agents/deep-research.md` | Deep research subagent (invoke with @deep-research) |