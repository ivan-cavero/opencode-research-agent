#!/usr/bin/env bash
# OpenCode Research Agent Installer — Linux/macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/ivan-cavero/opencode-research-agent/main/install.sh | bash
#
# TUI with arrow-key checklists. Detects Bun/Node, CLI/Desktop, optional MCPs.

set -e

REPO="ivan-cavero/opencode-research-agent"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
HOME_CONFIG_DIR="$HOME/.config/opencode"
AGENTS_DIR="$HOME_CONFIG_DIR/agents"

# ── Detect interactive ─────────────────────────────────────────────────
INTERACTIVE=false
if [ -t 0 ] && [ -t 2 ]; then
    INTERACTIVE=true
fi

# ── ANSI colors ────────────────────────────────────────────────────────
if [ -t 1 ]; then
    BOLD='\033[1m'; DIM='\033[2m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; RED='\033[0;31m'; GRAY='\033[0;90m'
    NC='\033[0m'
    CHECKED='✓'; UNCHECKED='○'; CURSOR='▸'
else
    BOLD=''; DIM=''; GREEN=''; YELLOW=''; CYAN=''; RED=''; GRAY=''; NC=''
    CHECKED='[*]'; UNCHECKED='[ ]'; CURSOR='>'
fi

info()  { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
note()  { echo -e "${GRAY}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
title() { echo -e "\n${BOLD}$1${NC}"; echo -e "${BOLD}$(printf '%*s' ${#1} '' | tr ' ' '─')${NC}"; }

# ── TUI Checklist ─────────────────────────────────────────────────────
# Items format: "key|Description|default"  (default: "yes" or "no")
# If default is omitted, defaults to "no"
checklist() {
    local header="$1"
    shift
    local items=("$@")
    local count=${#items[@]}

    local keys=(); local descs=(); local defaults=()
    local idx=0
    for item in "${items[@]}"; do
        IFS='|' read -r key desc default <<< "$item"
        keys+=("$key"); descs+=("$desc")
        [ "$default" = "yes" ] && defaults[$idx]=true || defaults[$idx]=false
        idx=$((idx + 1))
    done

    # Non-interactive: return items with default="yes"
    if [ "$INTERACTIVE" != true ]; then
        local result=""
        for ((i=0; i<count; i++)); do
            if [ "${defaults[$i]}" = true ]; then
                result="$result ${keys[$i]}"
            fi
        done
        echo "${result# }"
        return
    fi

    # Interactive TUI
    local selected=()
    for ((i=0; i<count; i++)); do selected[$i]=${defaults[$i]:-false}; done
    local cursor=0
    local row=0

    local saved_stty
    saved_stty=$(stty -g 2>/dev/null) || true
    stty -echo -icanon 2>/dev/null || true
    exec < /dev/tty 2>/dev/null || true

    render() {
        [ $row -gt 0 ] && tput cuu $row 2>/dev/null || true
        row=0
        echo ""
        echo -e " ${BOLD}${header}${NC}"
        row=$((row + 2))
        for ((i=0; i<count; i++)); do
            local mark="${GRAY}${UNCHECKED}${NC}"
            [ "${selected[$i]}" = true ] && mark="${GREEN}${CHECKED}${NC}"
            local arrow=" "
            [ "$i" = "$cursor" ] && arrow="${CYAN}${CURSOR}${NC}"
            echo -e " ${arrow} ${mark} ${BOLD}${keys[$i]}${NC}  ${GRAY}${descs[$i]}${NC}"
            row=$((row + 1))
        done
        echo ""
        echo -e " ${GRAY}↑↓ arrows · space toggle · enter confirm${NC}"
        row=$((row + 2))
    }

    render
    while true; do
        local key
        IFS= read -r -s -N1 key 2>/dev/null
        if [ "$key" = $'\x1b' ]; then
            local key2
            IFS= read -r -s -N2 -t 0.1 key2 2>/dev/null || true
            case "$key2" in
                '[A') ((cursor--)); [ "$cursor" -lt 0 ] && cursor=$((count - 1)); render ;;
                '[B') ((cursor++)); [ "$cursor" -ge "$count" ] && cursor=0; render ;;
            esac
        elif [ "$key" = ' ' ]; then
            selected[$cursor]=$([ "${selected[$cursor]}" = true ] && echo false || echo true)
            render
        elif [ -z "$key" ] || [ "$key" = $'\x0a' ] || [ "$key" = $'\x0d' ]; then
            break
        fi
    done

    stty "$saved_stty" 2>/dev/null || true

    local result=""
    for ((i=0; i<count; i++)); do
        [ "${selected[$i]}" = true ] && result="$result ${keys[$i]}"
    done
    echo "${result# }"
}

# ═══════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}  OpenCode Research Agent Installer${NC}"
echo -e "${GRAY}  Interactive TUI — arrows · space · enter${NC}"
echo ""

# ── Step 1: Runtimes ──────────────────────────────────────────────────
title "Runtime"

NODE_VER=""; BUN_VER=""
command -v node &>/dev/null && NODE_VER=$(node --version) && info "  Node ${NODE_VER}"
command -v node &>/dev/null || warn "  Node not installed"
command -v bun &>/dev/null && BUN_VER=$(bun --version) && info "  Bun v${BUN_VER}"
command -v bun &>/dev/null || warn "  Bun not installed"

if [ -z "$NODE_VER" ] && [ -z "$BUN_VER" ]; then
    error "  No runtime found. Install Node (https://nodejs.org) or Bun (https://bun.sh)"
    exit 1
fi

# Runtime selection: pick if both available
RUNTIME="bun"
if [ -n "$BUN_VER" ] && [ -n "$NODE_VER" ]; then
    # Both available — let user choose
    echo ""
    RUNTIME=$(checklist "Runtime to use?" "bun|Bun (faster startup, recommended)|yes" "node|Node.js|no")
    [ -z "$RUNTIME" ] && RUNTIME="bun"
    info "  → Using ${RUNTIME}"
elif [ -n "$BUN_VER" ]; then
    info "  → Using Bun"
    RUNTIME="bun"
else
    info "  → Using Node"
    RUNTIME="node"
fi

# ── Step 2: OpenCode detection ────────────────────────────────────────
title "OpenCode"

HAS_CLI=false; HAS_DESKTOP=false

command -v opencode &>/dev/null && HAS_CLI=true && info "  CLI: $(which opencode)"
[ -x "$HOME/.opencode/bin/opencode" ] && { HAS_CLI=true; info "  CLI: ~/.opencode/bin/opencode"; }

# Desktop: RPM → /opt/OpenCode/
[ -x "/opt/OpenCode/ai.opencode.desktop" ] && { HAS_DESKTOP=true; info "  Desktop: /opt/OpenCode/ (RPM)"; }
# Desktop: macOS
[ -d "/Applications/OpenCode.app" ] && { HAS_DESKTOP=true; info "  Desktop: /Applications/OpenCode.app"; }
# Desktop: AppImage
for d in "$HOME/Applications" "$HOME/Desktop" "$HOME/.local/bin"; do
    ls "$d"/OpenCode*.AppImage 2>/dev/null >/dev/null && { HAS_DESKTOP=true; info "  Desktop: AppImage in $d"; break; }
done
# Desktop: Flatpak
flatpak info ai.opencode.desktop 2>/dev/null >/dev/null && { HAS_DESKTOP=true; info "  Desktop: Flatpak"; }
# Desktop: Snap
[ -x "/snap/bin/opencode" ] && { HAS_DESKTOP=true; info "  Desktop: Snap"; }

if ! $HAS_CLI && ! $HAS_DESKTOP; then
    error "  No OpenCode found. Install: https://opencode.ai/download"
    exit 1
fi

# Build target checklist. "both" = special case: select both cli+desktop
TARGET_ITEMS=()
if $HAS_CLI && $HAS_DESKTOP; then
    TARGET_ITEMS+=("cli|OpenCode CLI (terminal)|no")
    TARGET_ITEMS+=("desktop|OpenCode Desktop (GUI app)|no")
    TARGET_ITEMS+=("both|Configure both CLI and Desktop|yes")
elif $HAS_CLI; then
    TARGET_ITEMS+=("cli|OpenCode CLI (terminal)|yes")
elif $HAS_DESKTOP; then
    TARGET_ITEMS+=("desktop|OpenCode Desktop (GUI app)|yes")
fi

echo ""
TARGET=$(checklist "Install for?" "${TARGET_ITEMS[@]}")
# If "both" selected, expand to "cli desktop"
if [ "$TARGET" = "both" ]; then
    TARGET="cli desktop"
fi
[ -z "$TARGET" ] && TARGET="cli"
info "  Selected: $TARGET"

# ── Step 3: Download agents ───────────────────────────────────────────
title "Agents"

AGENTS=(research.md deep-research.md verifier.md code.md docs-writer.md)
echo -n "  Downloading 5 agents ... "
mkdir -p "$AGENTS_DIR"
OK=0
for agent in "${AGENTS[@]}"; do
    curl -fsSL "$RAW/agents/$agent" -o "$AGENTS_DIR/$agent" 2>/dev/null && OK=$((OK + 1))
done
if [ "$OK" -eq "${#AGENTS[@]}" ]; then
    echo -e "${GREEN}${OK}/${#AGENTS[@]} ✓${NC}"
else
    echo -e "${YELLOW}${OK}/${#AGENTS[@]} (some failed)${NC}"
fi

# ── Step 4: Config file ──────────────────────────────────────────────
title "Config"

CONFIG_FILE=""
if [ -f "$HOME_CONFIG_DIR/opencode.jsonc" ]; then
    CONFIG_FILE="$HOME_CONFIG_DIR/opencode.jsonc"
    note "  Found: opencode.jsonc"
elif [ -f "$HOME_CONFIG_DIR/opencode.json" ]; then
    CONFIG_FILE="$HOME_CONFIG_DIR/opencode.json"
    note "  Found: opencode.json"
fi

if [ -z "$CONFIG_FILE" ]; then
    FORMAT="jsonc"
    if [ "$INTERACTIVE" = true ]; then
        echo -n "  Config format? (json/jsonc) [${FORMAT}]: "
        read -r FORMAT_INPUT 2>/dev/null || true
        [ -n "$FORMAT_INPUT" ] && FORMAT="$FORMAT_INPUT"
    fi
    CONFIG_FILE="$HOME_CONFIG_DIR/opencode.$FORMAT"
    mkdir -p "$HOME_CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "default_agent": "research"
}
EOF
    info "  Created: $CONFIG_FILE"
fi

# ── Step 5: MCP selection ─────────────────────────────────────────────
title "MCP Servers (optional extras)"

MCP_ITEMS=(
    "searxng|Web search via SearXNG (Docker). Searches Google/Bing/DDG/Brave|yes"
    "arxiv|Academic paper search on arxiv.org|yes"
)

echo ""
MCP=$(checklist "Select MCPs to install (arrows + space)" "${MCP_ITEMS[@]}")
if [ -z "$MCP" ]; then
    warn "  None selected — MCPs skipped"
else
    info "  Selected: $MCP"
fi

# ── Step 6: Merge MCPs into config ────────────────────────────────────
if [ -n "$MCP" ]; then
    echo -n "  Merging MCPs into config ... "
    FRAGMENT_FILE=$(mktemp)
    if curl -fsSL "$RAW/opencode.json" -o "$FRAGMENT_FILE" 2>/dev/null && [ -s "$FRAGMENT_FILE" ]; then
        # Filter fragment to only selected MCPs
        JQ_FILTER='{mcp: .mcp | with_entries(select('
        FIRST=true
        for m in $MCP; do
            if [ "$FIRST" = true ]; then
                JQ_FILTER="$JQ_FILTER.key == \"$m\""
                FIRST=false
            else
                JQ_FILTER="$JQ_FILTER or .key == \"$m\""
            fi
        done
        JQ_FILTER="$JQ_FILTER))}"

        F=$(mktemp)
        if command -v jq &>/dev/null; then
            jq "$JQ_FILTER" "$FRAGMENT_FILE" > "$F" 2>/dev/null || cp "$FRAGMENT_FILE" "$F"
        else
            cp "$FRAGMENT_FILE" "$F"
        fi

        if [ -s "$F" ] && command -v jq &>/dev/null && jq -e '.mcp | length > 0' "$F" >/dev/null 2>&1; then
            jq -s '.[0] as $e | .[1] as $f |
              ($e + (if $e.mcp then {} else {mcp:{}} end)) |
              .mcp = (.mcp + $f.mcp) |
              if .default_agent == null then .default_agent = "research" else . end
            ' "$CONFIG_FILE" "$F" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}skipped (no matching MCPs)${NC}"
        fi
        rm -f "$F"
    fi
    rm -f "$FRAGMENT_FILE"
fi

# ── Step 7: Custom provider ──────────────────────────────────────────
title "Custom provider (optional)"

if [ "$INTERACTIVE" = true ]; then
    echo ""
    ADD=$(checklist "Add a custom LLM provider?" "provider|Configure an OpenAI-compatible provider|no")
    if [ -n "$ADD" ]; then
        echo ""
        info "  Provider ID (lowercase, no spaces):"
        echo -n "  > "; read -r PROVIDER_ID
        [ -z "$PROVIDER_ID" ] && PROVIDER_ID="myprovider"
        echo -n "  Display name [My Provider]: "; read -r DISPLAY_NAME
        [ -z "$DISPLAY_NAME" ] && DISPLAY_NAME="My Provider"
        echo -n "  Base URL [https://api.openai.com/v1]: "; read -r BASE_URL
        [ -z "$BASE_URL" ] && BASE_URL="https://api.openai.com/v1"
        echo -n "  API key (blank to skip): "; read -r API_KEY
        echo -n "  Default model [gpt-4o]: "; read -r MODEL_NAME
        [ -z "$MODEL_NAME" ] && MODEL_NAME="gpt-4o"

        PROVIDER_JSON=$(mktemp)
        echo '{}' | jq \
          --arg id "$PROVIDER_ID" \
          --arg name "$DISPLAY_NAME" \
          --arg url "$BASE_URL" \
          --arg key "${API_KEY:-}" \
          --arg model "$MODEL_NAME" \
          --arg mname "$DISPLAY_NAME Default" \
          '.provider = {($id): {
            "npm": "@ai-sdk/openai-compatible",
            "name": $name,
            "options": ({baseURL: $url} + if $key != "" then {apiKey: $key} else {} end),
            "models": {($model): {
              "name": $mname,
              "tool_call": true,
              "limit": {context: 128000, output: 8192}
            }}
          }}' > "$PROVIDER_JSON"

        if command -v jq &>/dev/null; then
            jq -s '.[0] as $e | .[1] as $f |
              ($e + (if $e.provider then {} else {provider:{}} end)) |
              .provider = (.provider + $f.provider)
            ' "$CONFIG_FILE" "$PROVIDER_JSON" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            info "  ✓ Provider '$PROVIDER_ID' added"
        else
            warn "  jq missing — add manually:"
            cat "$PROVIDER_JSON"
        fi
        rm -f "$PROVIDER_JSON"
    fi
fi

# ── Step 8: Pre-download MCPs ─────────────────────────────────────────
if [ -n "$MCP" ]; then
    title "Pre-downloading MCP packages"
    for mcp in $MCP; do
        echo -n "  ${mcp} ... "
        case "$mcp" in
            searxng)
                if [ "$RUNTIME" = "bun" ]; then
                    bunx -y -p one-search-mcp one-search-mcp --version &>/dev/null && info "✓" || warn "on first use"
                else
                    npx -y -p one-search-mcp one-search-mcp --version &>/dev/null && info "✓" || warn "on first use"
                fi
                ;;
            arxiv)
                if [ "$RUNTIME" = "bun" ]; then
                    bunx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version &>/dev/null && info "✓" || warn "on first use"
                else
                    npx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version &>/dev/null && info "✓" || warn "on first use"
                fi
                ;;
        esac
    done
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  ─── Installation complete ───${NC}"
echo ""
echo "  Runtime: $RUNTIME"
echo "  Targets: $TARGET"
echo "  Config:  $CONFIG_FILE"
echo "  MCPs:    ${MCP:-none}"
echo ""
if [[ "$MCP" == *"searxng"* ]]; then
    echo -e "${YELLOW}  ── Start SearXNG before using research ──${NC}"
    echo "  docker run -d --name searxng -p 8080:8080 searxng/searxng"
    echo ""
fi
echo "  Restart OpenCode. Agents appear as tabs."
echo ""
