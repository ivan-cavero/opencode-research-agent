# OpenCode Research Agent Installer — Windows Bootstrap
# Downloads and runs the cross-platform Node.js installer.
# Uses Bun if available, falls back to Node.
# Usage: irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex

$URL = "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs"

# Detect runtime
$RUNTIME = $null
if (Get-Command bun -ErrorAction SilentlyContinue) {
    $RUNTIME = "bun"
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
    $RUNTIME = "node"
} else {
    Write-Host "  Node.js or Bun required. Install: https://nodejs.org or https://bun.sh" -ForegroundColor Red
    exit 1
}

# Download to temp file with .mjs extension
$TMP = "$env:TEMP\opencode-installer-$PID.mjs"
try {
    Invoke-WebRequest -Uri $URL -OutFile $TMP -UseBasicParsing -ErrorAction Stop
    & $RUNTIME $TMP
} finally {
    Remove-Item $TMP -ErrorAction SilentlyContinue
}
