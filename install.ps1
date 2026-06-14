# Research Agent for OpenCode — Windows Installer
# Usage: irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex

$REPO = "ivan-cavero/opencode-research-agent"
$BRANCH = "main"
$CONFIG_DIR = "$env:USERPROFILE\.config\opencode"
$AGENTS_DIR = "$CONFIG_DIR\agents"
$RAW = "https://raw.githubusercontent.com/$REPO/$BRANCH"

Write-Host "=== OpenCode Research Agent Installer ===" -ForegroundColor Cyan
Write-Host ""

# 1. Install bun if missing
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "[1/4] Installing bun..." -ForegroundColor Yellow
    powershell -c "irm bun.sh/install.ps1 | iex"
} else {
    Write-Host "[1/4] bun already installed" -ForegroundColor Green
}

# 2. Create config directories
Write-Host "[2/4] Creating config directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $AGENTS_DIR -Force | Out-Null

# 3. Download config files
Write-Host "[3/4] Downloading agent files..." -ForegroundColor Yellow
Invoke-WebRequest -Uri "$RAW/opencode.json" -OutFile "$CONFIG_DIR\opencode.json" -UseBasicParsing
Invoke-WebRequest -Uri "$RAW/agents/research.md" -OutFile "$AGENTS_DIR\research.md" -UseBasicParsing
Invoke-WebRequest -Uri "$RAW/agents/deep-research.md" -OutFile "$AGENTS_DIR\deep-research.md" -UseBasicParsing

# 4. Install MCP packages
Write-Host "[4/4] Installing MCP packages (first run will be slower)..." -ForegroundColor Yellow
& "bunx" -y -p one-search-mcp one-search-mcp --version 2>$null
& "bunx" -y -p mcp-omnisearch mcp-omnisearch --version 2>$null

Write-Host ""
Write-Host "=== Installation complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Start SearXNG before using the research agent:" -ForegroundColor Yellow
Write-Host "  podman run -d --name searxng -p 8080:8080 searxng/searxng" -ForegroundColor Cyan
Write-Host "  (or: docker run -d --name searxng -p 8080:8080 searxng/searxng)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then restart OpenCode. The Research agent will appear as a tab." -ForegroundColor Green