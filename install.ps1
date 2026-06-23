# OpenCode Research Agent Installer — Windows Bootstrap
# Requires Node.js. Downloads and runs the cross-platform Node.js installer.
# Usage: irm https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.ps1 | iex

$INSTALLER_URL = "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs"

# Check Node.js
try {
    $nodeVersion = node --version
} catch {
    Write-Host "  Node.js is required. Install it: https://nodejs.org" -ForegroundColor Red
    exit 1
}

# Download installer to temp file
$TMP = [System.IO.Path]::GetTempFileName()
try {
    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $TMP -UseBasicParsing
    node $TMP
} finally {
    Remove-Item $TMP -ErrorAction SilentlyContinue
}
