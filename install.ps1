# OpenCode Research Agent Installer — Windows Bootstrap
$TMP = Join-Path $env:TEMP "opencode-install-$PID"
New-Item -ItemType Directory -Path $TMP -Force | Out-Null
try {
    Set-Location $TMP
    npm init -y 2>&1 | Out-Null
    npm install @clack/prompts kleur 2>&1 | Out-Null
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install-core.mjs" -OutFile "$TMP\install.mjs" -UseBasicParsing
    node "$TMP\install.mjs"
} finally {
    Remove-Item $TMP -Recurse -Force -ErrorAction SilentlyContinue
}
