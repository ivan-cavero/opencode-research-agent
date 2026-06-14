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

# 2. Download agent files
Write-Host "[2/4] Creating agent files..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $AGENTS_DIR -Force | Out-Null
Invoke-WebRequest -Uri "$RAW/agents/research.md" -OutFile "$AGENTS_DIR\research.md" -UseBasicParsing
Invoke-WebRequest -Uri "$RAW/agents/deep-research.md" -OutFile "$AGENTS_DIR\deep-research.md" -UseBasicParsing
Invoke-WebRequest -Uri "$RAW/agents/verifier.md" -OutFile "$AGENTS_DIR\verifier.md" -UseBasicParsing

# 3. Merge MCPs into existing opencode.json (preserves your config)
Write-Host "[3/4] Adding MCPs to your existing config..." -ForegroundColor Yellow
$CONFIG_FILE = "$CONFIG_DIR\opencode.json"
$MCP_FRAGMENT = Invoke-RestMethod -Uri "$RAW/opencode.json" -UseBasicParsing

if (Test-Path $CONFIG_FILE) {
    $config = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json
    $mcp = $MCP_FRAGMENT.mcp
    if (-not $config.mcp) { $config | Add-Member -NotePropertyName mcp -NotePropertyValue @{} }
    foreach ($key in $mcp.PSObject.Properties.Name) {
        $config.mcp | Add-Member -MemberType NoteProperty -Name $key -Value $mcp.$key -Force
    }
    if (-not $config.default_agent) { $config | Add-Member -NotePropertyName default_agent -NotePropertyValue "research" }
    $config | ConvertTo-Json -Depth 10 | Set-Content $CONFIG_FILE -Encoding UTF8
    Write-Host "  > Existing config preserved. MCPs added: searxng, omnisearch, arxiv" -ForegroundColor Gray
} else {
    $config = $MCP_FRAGMENT
    $config | Add-Member -NotePropertyName default_agent -NotePropertyValue "research"
    $config | Add-Member -NotePropertyName '$schema' -NotePropertyValue "https://opencode.ai/config.json" -Force
    $config | ConvertTo-Json -Depth 10 | Set-Content $CONFIG_FILE -Encoding UTF8
}

# 4. Cache MCP packages
Write-Host "[4/4] Caching MCP packages..." -ForegroundColor Yellow
& "bunx" -y -p one-search-mcp one-search-mcp --version 2>$null
& "bunx" -y -p mcp-omnisearch mcp-omnisearch --version 2>$null
& "bunx" -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>$null

Write-Host ""
Write-Host "=== Installation complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Start SearXNG before using the research agent:" -ForegroundColor Yellow
Write-Host "  podman run -d --name searxng -p 8080:8080 searxng/searxng" -ForegroundColor Cyan
Write-Host "  (or: docker run -d --name searxng -p 8080:8080 searxng/searxng)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then restart OpenCode. The Research agent will appear as a tab." -ForegroundColor Green