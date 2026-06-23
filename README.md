# OpenCode Research Agent

Elite research agents for OpenCode with free, self-hosted web search via SearXNG.

## Architecture

```
┌─ Agents ──────────────────────────────────────────┐
│                                                    │
│  Research Agent    Code Agent     Docs Writer      │
│  ├ web search      ├ code review  ├ doc generation │
│  ├ arxiv papers    ├ refactoring  └ stop-slop gate │
│  ├ comparisons     ├ security                       │
│  └ subagents       └ writing                        │
│       ├ @deep-research                              │
│       └ @verifier                                   │
│                                                    │
│  ┌─ MCP Servers (optional) ────────────────────┐   │
│  │  searxng — Web search (needs Docker)        │   │
│  │  arxiv   — Academic paper search            │   │
│  └─────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────┘
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

## Interactive TUI

The installer uses a modern terminal UI with spinners and arrow-key checklists:

```
  ┌──────────────────────────────────────┐
  │  OpenCode Research Agent Installer    │
  │  arrows · space · enter                │
  └──────────────────────────────────────┘


  ┌─ Runtime
  │
  │   Node v24.16.0
  │   Bun v1.3.12
  │
  └─


  ❯ ◉ bun    Bun (faster startup)
    ◯ node   Node.js

    arrows · space · enter
```

| Step | What happens |
|------|-------------|
| Runtime | Detects Bun and Node.js. If both, shows a checklist to pick one |
| OpenCode | Detects CLI and Desktop installations (RPM, macOS, AppImage, Flatpak) |
| Targets | Shows checklist: CLI, Desktop, or Both (pre-selected based on what's detected) |
| Agents | Downloads 5 agents with animated spinners |
| Config | Finds existing `opencode.jsonc` or `opencode.json` |
| MCPs | Checklist with searxng/arxiv pre-selected (optional) |
| Default Agent | Pick which agent opens by default (research pre-selected) |
| Provider | Guided setup with optional model fetch from API (`/v1/models`) |
| Pre-download | Downloads selected MCP packages with spinners |

## Prerequisites

- **OpenCode** installed (CLI, Desktop, or both)
- **Bun** or **Node.js** (one is enough)
- **Docker** or **Podman** (for SearXNG)

## Start SearXNG

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
```

## Files

| File | Purpose |
|------|---------|
| `install.sh` | Bootstrap (10 lines) — downloads and runs the core installer |
| `install-core.sh` | Full TUI installer with spinners and checklists |
| `install.ps1` | Windows installer |
| `opencode.json` | MCP fragment (merged into config) |
| `agents/*.md` | 5 agent prompt files |

## Agents

| Agent | Purpose |
|-------|---------|
| **Research** | Web search, arxiv, comparisons, deep explanations |
| **Deep Research** | Exhaustive multi-loop investigation |
| **Verifier** | Devil's advocate — challenges conclusions |
| **Code** | Code review, refactoring, security analysis, writing |
| **Docs Writer** | Documentation generation with stop-slop quality gates |

Use `@agent-name` from any agent to delegate: `@deep-research best RAG chunking strategy`
