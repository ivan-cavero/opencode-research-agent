# OpenCode Research Agent Installer — Windows Bootstrap
# Usage: irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex

$TMP = Join-Path $env:TEMP "opencode-install-$PID"
New-Item -ItemType Directory -Path $TMP -Force | Out-Null
try {
    Write-Host ""
    Write-Host "  OpenCode Research Agent Installer" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Install deps
    Write-Host "  [1/3] Installing dependencies..." -ForegroundColor Yellow
    Set-Location $TMP
    npm init -y 2>&1 | Out-Null
    npm install @clack/prompts kleur 2>&1 | Out-Null
    Write-Host "  [✓] Dependencies ready" -ForegroundColor Green

    # Step 2: Download installer
    Write-Host "  [2/3] Downloading installer..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -OutFile "$TMP\install.mjs" -UseBasicParsing
    Write-Host "  [✓] Installer downloaded" -ForegroundColor Green

    # Step 3: Run
    Write-Host "  [3/3] Starting installer..." -ForegroundColor Yellow
    Write-Host ""
    node "$TMP\install.mjs"
} finally {
    Remove-Item $TMP -Recurse -Force -ErrorAction SilentlyContinue
}
