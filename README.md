# OpenCode Research Agent

Elite research agents for OpenCode with free, self-hosted web search via SearXNG.

## Architecture

```
┌─ Installer (Node.js — cross-platform) ─────────────────────┐
│                                                             │
│  ┌─ Agents ───────────────────────┐  ┌─ MCPs (optional) ─┐ │
│  │                                 │  │                     │ │
│  │  Research Agent  (web + arxiv)  │  │  searxng           │ │
│  │  Deep Research   (exhaustive)   │  │  arxiv             │ │
│  │  Verifier        (devil's adv)  │  │                     │ │
│  │  Code Agent      (review/write) │  └─────────────────────┘ │
│  │  Docs Writer     (docs gen)     │                           │
│  │                                 │  ┌─ Providers ─────────┐ │
│  │  @deep-research                 │  │                     │ │
│  │  @verifier                      │  │  NaN (built-in)     │ │
│  │                                 │  │  OpenAI / Custom    │ │
│  └─────────────────────────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Cost: 0€** — no API keys needed.

## Install

One command. Works on Windows, macOS, and Linux.

### Linux / macOS
```bash
curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash
```

### Windows
```powershell
irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex
```

Both download and run the same cross-platform Node.js installer.

## Requirements

- **OpenCode** installed (CLI, Desktop, or both)
- **Node.js** (v18+) — [nodejs.org](https://nodejs.org)
- **Docker** or **Podman** (for SearXNG web search)

## Interactive TUI

```



  ┌──────────────────────────────────────────┐
  │  OpenCode Research Agent Installer        │
  │  arrows · space · enter · cross-platform  │
  └──────────────────────────────────────────┘


  ┌─ Runtime
  │
  │   Node v24.16.0
  │   Running on Node.js — cross-platform
  │
  └─



  ┌─ OpenCode
  │
  │   CLI detected
  │   Desktop detected
  │
  └─


  Install for?
  ❯ ● Both CLI + Desktop  recommended
    ○ CLI (terminal)
    ○ Desktop (GUI)

    arrows · enter


  MCP Servers (optional)
  ❯ ◉ searxng  web search (needs Docker)
    ◉ arxiv    academic papers

    arrows · space · enter


  Select provider
  ❯ ● NaN              nan.builders — free credits included
    ○ OpenAI            api.openai.com
    ○ Custom            any OpenAI-compatible API

    arrows · enter


  Default model
  ❯ ● deepseek-v4-flash  1M context, reasoning
    ○ qwen3.6
    ○ gemma4

    arrows · enter
```

## Features

| Feature | Detail |
|---------|--------|
| **Interactive TUI** | Full arrow-key navigation, checkboxes, spinners |
| **Cross-platform** | Same Node.js installer runs on Win/Mac/Linux |
| **NaN built-in** | Pre-configured NaN provider with model fetch |
| **Custom providers** | Add any OpenAI-compatible provider |
| **Model discovery** | Fetches `/v1/models` from provider API |
| **5 agents** | Research, Deep Research, Verifier, Code, Docs Writer |
| **Optional MCPs** | Enable/disable searxng, arxiv and more |
| **Spinners** | Animated loading during downloads |

## Start SearXNG

```bash
docker run -d --name searxng -p 8080:8080 searxng/searxng
```

Then restart OpenCode. Agents appear as tabs.

## Files

| File | Purpose |
|------|---------|
| `install.sh` | Linux/macOS bootstrap (10 lines) |
| `install.ps1` | Windows bootstrap (10 lines) |
| `install-core.mjs` | Cross-platform Node.js TUI installer |
| `opencode.json` | MCP fragment (merged into config) |
| `agents/*.md` | 5 agent prompt files |
