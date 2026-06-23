# OpenCode Research Agent

Elite research agent for OpenCode with free, self-hosted web search via SearXNG.

## Architecture

```
Research Agent (primary)    Code Agent    Docs Writer Agent
├── websearch + webfetch    ├── review    ├── code-aware docs
├── SearXNG MCP             ├── refactor  └── stop-slop gates
├── arXiv MCP               ├── security
└── subagents:              └── write
    ├── @deep-research
    └── @verifier
         │
         ▼
     SearXNG (Docker/Podman) — meta search engine (Google, Bing, DuckDuckGo, Brave)
```

**Cost: 0€** — no API keys needed.

## Install

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash
```

### Windows
```powershell
irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex
```

## Interactive flow

The installer is a **TUI (terminal UI)** with arrow-key navigation:

```
▸ ○ searxng  Web search via SearXNG (Docker)
  ○ arxiv    Academic paper search on arxiv.org

  ↑↓ arrows · space toggle · enter confirm
```

| Step | What happens |
|------|-------------|
| 1 | Detects Bun and Node.js — uses Bun if available |
| 2 | Detects OpenCode CLI and Desktop — selects what to configure |
| 3 | Downloads 5 agents to `~/.config/opencode/agents/` |
| 4 | Finds existing `opencode.json` or `opencode.jsonc` |
| 5 | Checklist: select MCPs to install (searxng, arxiv) — **optional** |
| 6 | Pre-downloads selected MCP packages for instant startup |
| 7 | Optionally guides through custom provider setup |

Everything is **interactive with checklists** (arrows, space, enter). In non-interactive mode (piped to bash), defaults are used.

## Prerequisites

- **OpenCode** installed (CLI, Desktop, or both)
- **Bun** or **Node.js** (one is enough; Bun recommended)
- **Docker** or **Podman** (to run SearXNG)

## Start SearXNG

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
```

Verify with `curl http://localhost:8080`.

## Agents

| Agent | File | Purpose |
|-------|------|---------|
| **Research** | `research.md` | Web search + arxiv + comparisons + explanations |
| **Deep Research** | `deep-research.md` | Exhaustive multi-loop investigation |
| **Verifier** | `verifier.md` | Devil's advocate — challenges conclusions |
| **Code** | `code.md` | Code review, refactoring, security analysis, writing |
| **Docs Writer** | `docs-writer.md` | Documentation from code with stop-slop quality gates |

Use `@agent-name` from any agent: `@deep-research best RAG chunking strategy`

## Usage

| Intent | Example |
|--------|---------|
| Explanatory | `what is PagedAttention?` |
| Build advice | `I want to build an AI inference server` |
| Comparison | `compare vLLM vs SGLang` |
| Deep dive | `@deep-research RAG for 5M documents` |
| Code review | `review this PR` |
| Docs | `write API docs for the auth module` |

## Files

| File | Purpose |
|------|---------|
| `opencode.json` | MCP fragment (merged into your config) |
| `install.sh` | Linux/macOS installer |
| `install.ps1` | Windows installer |
| `agents/*.md` | Agent prompt files |
