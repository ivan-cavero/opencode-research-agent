# OpenCode Research Agent Installer — Windows
# Usage: (or: irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex)
#
# Features:
#   - Detects OpenCode CLI and Desktop installations
#   - Selects runtime (Bun or Node)
#   - Installs 5 agents: research, deep-research, verifier, code, docs-writer
#   - Interactive MCP selection with descriptions
#   - Guided custom provider setup (writes to config)
#   - Detects opencode.json and opencode.jsonc
#   - Pre-downloads selected MCP packages for instant startup

$REPO = "ivan-cavero/opencode-research-agent"
$BRANCH = "main"
$RAW = "https://raw.githubusercontent.com/$REPO/$BRANCH"
$CONFIG_DIR = "$env:USERPROFILE\.config\opencode"
$AGENTS_DIR = "$CONFIG_DIR\agents"

Write-Host ""
Write-Host "  OpenCode Research Agent Installer" -ForegroundColor Cyan
Write-Host "  " -ForegroundColor Cyan
Write-Host ""

function Write-Info  { Write-Host "  $($args[0])" -ForegroundColor Green }
function Write-Warn  { Write-Host "  $($args[0])" -ForegroundColor Yellow }
function Write-Note  { Write-Host "  $($args[0])" -ForegroundColor DarkGray }
function Write-Prompt($text) { return Read-Host "  $text" }

# ── Step 1: Detect Runtimes ─────────────────────────────────────────────
Write-Host "  Runtime detection" -ForegroundColor White
Write-Host "  ────────────────" -ForegroundColor White

$NODE_VERSION = $null
$BUN_VERSION = $null
$SELECTED_RUNTIME = "bun"

try {
    $NODE_VERSION = node --version 2>$null
    Write-Info "Node found: $NODE_VERSION"
} catch {
    Write-Warn "Node not installed"
}

try {
    $BUN_VERSION = bun --version 2>$null
    Write-Info "Bun found: v$BUN_VERSION"
} catch {
    Write-Warn "Bun not installed"
}

if (-not $NODE_VERSION -and -not $BUN_VERSION) {
    Write-Host ""
    Write-Warn "No runtime found. Install Bun or Node first:"
    Write-Note "  Bun:  powershell -c `"irm bun.sh/install.ps1 | iex`""
    Write-Note "  Node: https://nodejs.org/"
    exit 1
}

$IsInteractive = $Host.UI.RawUI -and $Host.UI.RawUI.WindowSize

if ($IsInteractive) {
    Write-Host ""
    if ($BUN_VERSION -and $NODE_VERSION) {
        $RUNTIME_INPUT = Write-Prompt "Which runtime to use? (bun/node) [bun]: "
        $SELECTED_RUNTIME = if ($RUNTIME_INPUT) { $RUNTIME_INPUT } else { "bun" }
    } elseif ($BUN_VERSION) {
        Write-Info "Only Bun available — using bun"
        $SELECTED_RUNTIME = "bun"
    } else {
        Write-Info "Only Node available — using node"
        $SELECTED_RUNTIME = "node"
    }
}

if ($SELECTED_RUNTIME -eq "bun" -and -not $BUN_VERSION) {
    Write-Warn "Bun not installed, falling back to node"
    $SELECTED_RUNTIME = "node"
}
if ($SELECTED_RUNTIME -eq "node" -and -not $NODE_VERSION) {
    Write-Warn "Node not installed, falling back to bun"
    $SELECTED_RUNTIME = "bun"
}

Write-Info "Using: $SELECTED_RUNTIME"

# ── Step 2: Detect OpenCode targets ─────────────────────────────────────
Write-Host ""
Write-Host "  OpenCode detection" -ForegroundColor White
Write-Host "  ──────────────────" -ForegroundColor White

$HAS_CLI = $false
$HAS_DESKTOP = $false

# Check CLI
try {
    $CLI_VERSION = opencode --version 2>$null
    $HAS_CLI = $true
    Write-Info "OpenCode CLI detected: $CLI_VERSION"
} catch {
    Write-Warn "OpenCode CLI not detected"
}

# Check Desktop — common install paths on Windows
$DESKTOP_PATHS = @(
    "$env:LOCALAPPDATA\Programs\opencode-desktop",
    "${env:ProgramFiles}\OpenCode",
    "${env:ProgramFiles(x86)}\OpenCode"
)
foreach ($path in $DESKTOP_PATHS) {
    if (Test-Path "$path\opencode-desktop.exe") {
        $HAS_DESKTOP = $true
        Write-Info "OpenCode Desktop detected: $path"
        break
    }
}

if (-not $HAS_CLI -and -not $HAS_DESKTOP) {
    Write-Host ""
    Write-Warn "No OpenCode installation detected."
    Write-Note "Install OpenCode first: https://opencode.ai/download"
    exit 1
}

# Select targets
$SELECT_TARGETS = @()
if ($IsInteractive) {
    Write-Host ""
    Write-Host "  Which OpenCode installation(s) to configure?" -ForegroundColor White
    Write-Host ""

    $i = 1
    if ($HAS_CLI) {
        Write-Host "    $i) OpenCode CLI"
        $CLI_NUM = $i
        $i++
    }
    if ($HAS_DESKTOP) {
        Write-Host "    $i) OpenCode Desktop"
        $DESKTOP_NUM = $i
        $i++
    }
    if ($HAS_CLI -and $HAS_DESKTOP) {
        Write-Host "    $i) Both"
        $BOTH_NUM = $i
    }

    Write-Host ""
    $DEFAULT_NUM = if ($HAS_CLI -and $HAS_DESKTOP) { $BOTH_NUM } else { 1 }
    $TARGET_INPUT = Write-Prompt "Enter number (default: $DEFAULT_NUM): "

    if (-not $TARGET_INPUT) { $TARGET_INPUT = $DEFAULT_NUM }

    switch ($TARGET_INPUT) {
        $CLI_NUM  { $SELECT_TARGETS = @("cli") }
        $DESKTOP_NUM { $SELECT_TARGETS = @("desktop") }
        $BOTH_NUM { $SELECT_TARGETS = @("cli", "desktop") }
        "both"    { $SELECT_TARGETS = @("cli", "desktop") }
        "cli"     { $SELECT_TARGETS = @("cli") }
        "desktop" { $SELECT_TARGETS = @("desktop") }
        default   {
            if ($HAS_CLI -and $HAS_DESKTOP) {
                $SELECT_TARGETS = @("cli", "desktop")
            } elseif ($HAS_CLI) {
                $SELECT_TARGETS = @("cli")
            } else {
                $SELECT_TARGETS = @("desktop")
            }
        }
    }
} else {
    if ($HAS_CLI) { $SELECT_TARGETS += "cli" }
    if ($HAS_DESKTOP) { $SELECT_TARGETS += "desktop" }
    Write-Note "Non-interactive — configuring: $($SELECT_TARGETS -join ' ')"
}

# ── Step 3: Download agent files ────────────────────────────────────────
Write-Host ""
Write-Host "  Installing agents" -ForegroundColor White
Write-Host "  ─────────────────" -ForegroundColor White

New-Item -ItemType Directory -Path $AGENTS_DIR -Force | Out-Null
$AGENTS = @("research.md", "deep-research.md", "verifier.md", "code.md", "docs-writer.md")
$FAILED_AGENTS = @()

foreach ($agent in $AGENTS) {
    try {
        Invoke-WebRequest -Uri "$RAW/agents/$agent" -OutFile "$AGENTS_DIR\$agent" -UseBasicParsing -ErrorAction Stop
        Write-Host "  ✓ $agent" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ $agent (download failed)" -ForegroundColor Red
        $FAILED_AGENTS += $agent
    }
}

if ($FAILED_AGENTS.Count -gt 0) {
    Write-Warn "Some agents failed to download: $($FAILED_AGENTS -join ', ')"
}

# ── Step 4: Config file handling ────────────────────────────────────────
Write-Host ""
Write-Host "  Configuring OpenCode" -ForegroundColor White
Write-Host "  ───────────────────" -ForegroundColor White

$CONFIG_FILE = $null
if (Test-Path "$CONFIG_DIR\opencode.jsonc") {
    $CONFIG_FILE = "$CONFIG_DIR\opencode.jsonc"
    Write-Host "  Found: opencode.jsonc" -ForegroundColor Green
} elseif (Test-Path "$CONFIG_DIR\opencode.json") {
    $CONFIG_FILE = "$CONFIG_DIR\opencode.json"
    Write-Host "  Found: opencode.json" -ForegroundColor Green
}

if (-not $CONFIG_FILE) {
    $FORMAT = "jsonc"
    if ($IsInteractive) {
        $FORMAT_INPUT = Write-Prompt "Config format? (json/jsonc) [jsonc]: "
        if ($FORMAT_INPUT) { $FORMAT = $FORMAT_INPUT }
    }
    $CONFIG_FILE = "$CONFIG_DIR\opencode.$FORMAT"
    Write-Host "  Creating: $CONFIG_FILE" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $CONFIG_DIR -Force | Out-Null
    @{
        '$schema' = "https://opencode.ai/config.json"
        default_agent = "research"
    } | ConvertTo-Json -Depth 5 | Set-Content $CONFIG_FILE -Encoding UTF8
}

# ── Step 5: MCP selection ───────────────────────────────────────────────
Write-Host ""
Write-Host "  MCP servers" -ForegroundColor White
Write-Host "  ───────────" -ForegroundColor White

$MCP_SELECTED = @()

if ($IsInteractive) {
    Write-Host ""
    Write-Host "  Available MCP servers:" -ForegroundColor White
    Write-Host "    [1] searxng  - Web search via SearXNG (docker). Searches Google/Bing/DDG."
    Write-Host "    [2] arxiv    - Academic paper search on arxiv.org"
    Write-Host ""
    $MCP_INPUT = Write-Prompt "MCPs to install? (comma-separated numbers, default: 1,2): "
    if (-not $MCP_INPUT) { $MCP_INPUT = "1,2" }

    foreach ($num in ($MCP_INPUT -split ',' | ForEach-Object { $_.Trim() })) {
        switch ($num) {
            "1"  { $MCP_SELECTED += "searxng" }
            "2"  { $MCP_SELECTED += "arxiv" }
            default { Write-Warn "  Unknown option: $num" }
        }
    }
} else {
    $MCP_SELECTED = @("searxng", "arxiv")
    Write-Note "Non-interactive — installing: searxng arxiv"
}

# ── Step 6: Merge MCPs into config ──────────────────────────────────────
if ($MCP_SELECTED.Count -gt 0) {
    Write-Host "  Merging MCPs: $($MCP_SELECTED -join ' ')" -ForegroundColor Gray

    try {
        $MCP_FRAGMENT = Invoke-RestMethod -Uri "$RAW/opencode.json" -UseBasicParsing -ErrorAction Stop

        # Filter to selected MCPs only
        $FILTERED_MCP = @{}
        foreach ($mcp in $MCP_SELECTED) {
            if ($MCP_FRAGMENT.mcp.$mcp) {
                $FILTERED_MCP[$mcp] = $MCP_FRAGMENT.mcp.$mcp
            } else {
                Write-Warn "  MCP '$mcp' not found in fragment"
            }
        }

        if ($FILTERED_MCP.Count -gt 0) {
            # Read existing config
            $config = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json

            # Merge MCPs
            if (-not $config.mcp) { $config | Add-Member -NotePropertyName mcp -NotePropertyValue @{} }
            foreach ($key in $FILTERED_MCP.Keys) {
                $config.mcp | Add-Member -MemberType NoteProperty -Name $key -Value $FILTERED_MCP[$key] -Force
            }
            if (-not $config.default_agent) { $config | Add-Member -NotePropertyName default_agent -NotePropertyValue "research" }

            $json = $config | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($CONFIG_FILE, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  ✓ MCPs added: $($MCP_SELECTED -join ' ')" -ForegroundColor Green
        }
    } catch {
        Write-Warn "  Could not download or merge MCP fragment: $_"
    }
} else {
    Write-Host "  No MCPs selected — skipping" -ForegroundColor Gray
}

# ── Step 7: Custom provider ─────────────────────────────────────────────
Write-Host ""
Write-Host "  Custom provider" -ForegroundColor White
Write-Host "  ───────────────" -ForegroundColor White

if ($IsInteractive) {
    Write-Host ""
    $ADD_PROVIDER = Write-Prompt "Add a custom LLM provider? (y/n) [n]: "
    if (-not $ADD_PROVIDER) { $ADD_PROVIDER = "n" }

    if ($ADD_PROVIDER -match '^[Yy]') {
        Write-Host ""
        Write-Host "  Configure an OpenAI-compatible provider." -ForegroundColor White
        Write-Host ""

        # Provider ID
        do {
            $PROVIDER_ID = Write-Prompt "Provider ID (lowercase, no spaces) [myprovider]: "
            if (-not $PROVIDER_ID) { $PROVIDER_ID = "myprovider" }
            if ($PROVIDER_ID -match '^[a-z0-9_-]+$') { break }
            Write-Warn "  Only lowercase letters, numbers, hyphens, or underscores"
        } while ($true)

        $DISPLAY_NAME = Write-Prompt "Display name [My Provider]: "
        if (-not $DISPLAY_NAME) { $DISPLAY_NAME = "My Provider" }

        $BASE_URL = Write-Prompt "Base URL [https://api.openai.com/v1]: "
        if (-not $BASE_URL) { $BASE_URL = "https://api.openai.com/v1" }

        $API_KEY = Write-Prompt "API key (leave empty to skip): "

        $MODEL_NAME = Write-Prompt "Default model name [gpt-4o]: "
        if (-not $MODEL_NAME) { $MODEL_NAME = "gpt-4o" }

        # Read existing config
        $config = Get-Content $CONFIG_FILE -Raw | ConvertFrom-Json

        # Build provider entry
        $provider = @{
            npm = "@ai-sdk/openai-compatible"
            name = $DISPLAY_NAME
            options = @{ baseURL = $BASE_URL }
            models = @{
                $MODEL_NAME = @{
                    name = "$DISPLAY_NAME Default"
                    tool_call = $true
                    limit = @{ context = 128000; output = 8192 }
                }
            }
        }
        if ($API_KEY) {
            $provider.options.apiKey = $API_KEY
        }

        if (-not $config.provider) {
            $config | Add-Member -NotePropertyName provider -NotePropertyValue @{}
        }
        $config.provider | Add-Member -MemberType NoteProperty -Name $PROVIDER_ID -Value $provider -Force

        $json = $config | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($CONFIG_FILE, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  ✓ Provider '$PROVIDER_ID' added" -ForegroundColor Green
    }
} else {
    Write-Note "  Non-interactive — edit config manually to add a provider"
}

# ── Step 8: Pre-download MCP packages ───────────────────────────────────
Write-Host ""
Write-Host "  Pre-downloading MCP packages" -ForegroundColor White
Write-Host "  ────────────────────────────" -ForegroundColor White

if ($MCP_SELECTED.Count -gt 0) {
    Write-Host "  Downloading selected MCP packages for instant startup..." -ForegroundColor Gray
    Write-Host ""

    # Function to safely run a command with timeout
    function Invoke-WithTimeout {
        param($Command, $TimeoutSeconds = 30)
        $job = Start-Job -ScriptBlock { Invoke-Expression $using:Command }
        if (Wait-Job $job -Timeout $TimeoutSeconds) {
            Receive-Job $job
            Remove-Job $job
            return $true
        } else {
            Stop-Job $job
            Remove-Job $job
            return $false
        }
    }

    $RUNTIME_RUNNER = if ($SELECTED_RUNTIME -eq "bun") { "bunx" } else { "npx" }

    foreach ($mcp in $MCP_SELECTED) {
        switch ($mcp) {
            "searxng" {
                Write-Host -NoNewline "  one-search-mcp ... "
                $ok = Invoke-WithTimeout "$RUNTIME_RUNNER -y -p one-search-mcp one-search-mcp --version" 45
                if ($ok) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "will download on first use" -ForegroundColor Yellow }
            }
            "arxiv" {
                Write-Host -NoNewline "  @cyanheads/arxiv-mcp-server ... "
                $ok = Invoke-WithTimeout "$RUNTIME_RUNNER -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version" 45
                if ($ok) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "will download on first use" -ForegroundColor Yellow }
            }
        }
    }
} else {
    Write-Host "  No MCPs selected — nothing to pre-download" -ForegroundColor Gray
}

# ── Done ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ─────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Runtime:   $SELECTED_RUNTIME" -ForegroundColor White
Write-Host "  Targets:   $($SELECT_TARGETS -join ' ')" -ForegroundColor White
Write-Host "  Config:    $CONFIG_FILE" -ForegroundColor White
Write-Host "  Agents:    $($AGENTS -join ' ')" -ForegroundColor White
Write-Host "  MCPs:      $($MCP_SELECTED -join ' ')" -ForegroundColor White
Write-Host ""
if ($MCP_SELECTED -contains "searxng") {
    Write-Host "  ── Required: Start SearXNG ──" -ForegroundColor Yellow
    Write-Host "  Start SearXNG before using research agents:" -ForegroundColor Yellow
    Write-Host "    docker run -d --name searxng -p 8080:8080 searxng/searxng" -ForegroundColor Cyan
    Write-Host "    (or: podman run -d --name searxng -p 8080:8080 searxng/searxng)" -ForegroundColor Cyan
    Write-Host ""
}
Write-Host "  Restart OpenCode. Agents appear as tabs." -ForegroundColor Green
Write-Host "  Use research agent for: what-is, explain, comparisons, deep-dives" -ForegroundColor Gray
Write-Host "  Use code agent for:     code review, refactoring, writing" -ForegroundColor Gray
Write-Host "  Use docs-writer agent:  documentation generation" -ForegroundColor Gray
Write-Host "  ─────────────────────────────────────────" -ForegroundColor Cyan
Write-Host ""
