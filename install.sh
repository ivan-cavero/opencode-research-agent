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
# Must work even with `curl ... | bash`: stdin is a pipe but /dev/tty works.
INTERACTIVE=false
if [ -t 2 ] || [ -e /dev/tty ]; then
    # stderr is terminal OR /dev/tty exists → we can show TUI
    if [ -e /dev/tty ] && exec < /dev/tty 2>/dev/null; then
        INTERACTIVE=true
    fi
fi

# ── ANSI colors ────────────────────────────────────────────────────────
if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; RED='\033[0;31m'; GRAY='\033[0;90m'
    NC='\033[0m'
fi

info()  { echo -e "${GREEN}$1${NC}"; }
warn()  { echo -e "${YELLOW}$1${NC}"; }
note()  { echo -e "${GRAY}$1${NC}"; }
error() { echo -e "${RED}$1${NC}" >&2; }
title() { echo -e "\n${BOLD}  $1${NC}"; echo -e "${GRAY}  =====================${NC}"; }

# ── TUI Checklist ─────────────────────────────────────────────────────
# Items: "key|Description|default"  (default: "yes" or "no")
checklist() {
    local header="$1"; shift
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

    # Non-interactive: return all items with default="yes"
    if [ "$INTERACTIVE" != true ]; then
        local result=""
        for ((i=0; i<count; i++)); do
            [ "${defaults[$i]}" = true ] && result="$result ${keys[$i]}"
        done
        echo "${result# }"
        return
    fi

    # ── Interactive TUI ──
    local selected=()
    for ((i=0; i<count; i++)); do selected[$i]=${defaults[$i]:-false}; done
    local cursor=0; local row=0

    local saved_stty
    saved_stty=$(stty -g 2>/dev/null) || true
    stty -echo -icanon 2>/dev/null || true

    render() {
        [ $row -gt 0 ] && tput cuu $row 2>/dev/null || true
        row=0
        echo ""
        echo -e "  ${BOLD}${header}${NC}"
        row=$((row + 2))
        for ((i=0; i<count; i++)); do
            local mark="${GRAY}[ ]${NC}"
            [ "${selected[$i]}" = true ] && mark="${GREEN}[x]${NC}"
            local arrow="  "
            [ "$i" = "$cursor" ] && arrow="${CYAN}> ${NC}"
            echo -e " ${arrow}${mark} ${BOLD}${keys[$i]}${NC}  ${GRAY}${descs[$i]}${NC}"
            row=$((row + 1))
        done
        echo ""
        echo -e "  ${GRAY}arrows: move | space: toggle | enter: done${NC}"
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
            [ "${selected[$cursor]}" = true ] && selected[$cursor]=false || selected[$cursor]=true
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
echo -e "${GRAY}  Interactive TUI [arrows/space/enter]${NC}"
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

if [ -n "$BUN_VER" ] && [ -n "$NODE_VER" ]; then
    echo ""
    RUNTIME=$(checklist "Select runtime" "bun|Bun (faster)|yes" "node|Node.js|no")
    [ -z "$RUNTIME" ] && RUNTIME="bun"
    info "  Using: ${RUNTIME}"
elif [ -n "$BUN_VER" ]; then
    RUNTIME="bun"; info "  Using: Bun"
else
    RUNTIME="node"; info "  Using: Node"
fi

# ── Step 2: OpenCode detection ────────────────────────────────────────
title "OpenCode"

HAS_CLI=false; HAS_DESKTOP=false

command -v opencode &>/dev/null && { HAS_CLI=true; info "  CLI: $(which opencode)"; }
[ -x "$HOME/.opencode/bin/opencode" ] && { HAS_CLI=true; note "  CLI: ~/.opencode/bin/opencode"; }

# Desktop detection
[ -x "/opt/OpenCode/ai.opencode.desktop" ] && { HAS_DESKTOP=true; info "  Desktop: /opt/OpenCode/ (RPM)"; }
[ -d "/Applications/OpenCode.app" ] && { HAS_DESKTOP=true; info "  Desktop: /Applications/OpenCode.app"; }
for d in "$HOME/Applications" "$HOME/Desktop" "$HOME/.local/bin"; do
    ls "$d"/OpenCode*.AppImage 2>/dev/null >/dev/null && { HAS_DESKTOP=true; info "  Desktop: AppImage in $d"; break; }
done
flatpak info ai.opencode.desktop 2>/dev/null >/dev/null && { HAS_DESKTOP=true; info "  Desktop: Flatpak"; }

if ! $HAS_CLI && ! $HAS_DESKTOP; then
    error "  No OpenCode found. Install: https://opencode.ai/download"
    exit 1
fi

# Target selection
TARGET_ITEMS=()
if $HAS_CLI && $HAS_DESKTOP; then
    TARGET_ITEMS+=("cli|CLI (terminal)|no" "desktop|Desktop (GUI)|no" "both|Both CLI + Desktop|yes")
elif $HAS_CLI; then
    TARGET_ITEMS+=("cli|CLI (terminal)|yes")
else
    TARGET_ITEMS+=("desktop|Desktop (GUI)|yes")
fi

echo ""
TARGET=$(checklist "Install for?" "${TARGET_ITEMS[@]}")
[ "$TARGET" = "both" ] && TARGET="cli desktop"
[ -z "$TARGET" ] && TARGET="cli"
info "  Selected: $TARGET"

# ── Step 3: Download agents ───────────────────────────────────────────
title "Agents"

AGENTS=(research.md deep-research.md verifier.md code.md docs-writer.md)
mkdir -p "$AGENTS_DIR"
OK=0
for agent in "${AGENTS[@]}"; do
    curl -fsSL "$RAW/agents/$agent" -o "$AGENTS_DIR/$agent" 2>/dev/null && OK=$((OK + 1))
done
echo -n "  Downloaded "
[ "$OK" -eq "${#AGENTS[@]}" ] && info "${OK}/${#AGENTS[@]} ✓" || warn "${OK}/${#AGENTS[@]}"

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
    [ "$INTERACTIVE" = true ] && { echo -n "  Format (json/jsonc) [jsonc]: "; read -r FORMAT_INPUT; [ -n "$FORMAT_INPUT" ] && FORMAT="$FORMAT_INPUT"; }
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
    "searxng|Web search (needs SearXNG Docker)|yes"
    "arxiv|Academic papers on arxiv.org|yes"
)

echo ""
MCP=$(checklist "Select MCPs" "${MCP_ITEMS[@]}")
if [ -z "$MCP" ]; then
    warn "  None selected"
else
    info "  Selected: $MCP"
fi

# ── Step 6: Merge MCPs ────────────────────────────────────────────────
if [ -n "$MCP" ]; then
    echo -n "  Merging MCPs ... "
    FRAGMENT_FILE=$(mktemp)
    if curl -fsSL "$RAW/opencode.json" -o "$FRAGMENT_FILE" 2>/dev/null && [ -s "$FRAGMENT_FILE" ]; then
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
            info "ok"
        fi
        rm -f "$F"
    fi
    rm -f "$FRAGMENT_FILE"
fi

# ── Step 7: Default agent selection ───────────────────────────────────
title "Default Agent"

AGENT_NAMES=(research deep-research verifier code docs-writer)

echo ""
DEFAULT_AGENT=$(checklist "Default agent (first one with [x] becomes default)" \
    "research|Web search, comparisons, deep explanations|yes" \
    "deep-research|Exhaustive multi-loop investigation|no" \
    "verifier|Devil's advocate, challenges conclusions|no" \
    "code|Code review, refactoring, security, writing|no" \
    "docs-writer|Documentation generation|no")

if [ -n "$DEFAULT_AGENT" ]; then
    # First selected = default
    FIRST_AGENT=$(echo "$DEFAULT_AGENT" | cut -d' ' -f1)
    if command -v jq &>/dev/null; then
        jq --arg da "$FIRST_AGENT" '.default_agent = $da' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        info "  Default: $FIRST_AGENT"
    fi
fi

# ── Step 8: Custom provider ──────────────────────────────────────────
title "Custom provider (optional)"

if [ "$INTERACTIVE" = true ]; then
    echo ""
    ADD=$(checklist "Add a custom LLM provider?" "provider|Configure an OpenAI-compatible provider|no")
    if [ -n "$ADD" ]; then
        echo ""
        echo -n "  Provider ID [nan]: "; read -r PROVIDER_ID
        [ -z "$PROVIDER_ID" ] && PROVIDER_ID="nan"

        echo -n "  Display name [NaN]: "; read -r DISPLAY_NAME
        [ -z "$DISPLAY_NAME" ] && DISPLAY_NAME="NaN"

        echo -n "  Base URL [https://api.nan.builders/v1]: "; read -r BASE_URL
        [ -z "$BASE_URL" ] && BASE_URL="https://api.nan.builders/v1"

        echo -n "  API key: "; read -r API_KEY

        # Try to fetch models from the API (OpenAI-compatible /v1/models)
        MODELS_JSON=""
        if command -v curl &>/dev/null; then
            echo ""
            echo -n "  Fetching models from provider ... "
            if [ -n "$API_KEY" ]; then
                MODELS_JSON=$(curl -s -f --max-time 5 "${BASE_URL}/models" -H "Authorization: Bearer ${API_KEY}" 2>/dev/null || true)
            else
                MODELS_JSON=$(curl -s -f --max-time 5 "${BASE_URL}/models" 2>/dev/null || true)
            fi
            if [ -n "$MODELS_JSON" ] && echo "$MODELS_JSON" | jq -e '.data' >/dev/null 2>&1; then
                MODEL_COUNT=$(echo "$MODELS_JSON" | jq '.data | length')
                info "found ${MODEL_COUNT} models"
            else
                warn "could not fetch (enter model manually)"
                MODELS_JSON=""
            fi
        fi

        # Build model selection list
        MODEL_ITEMS=()
        if [ -n "$MODELS_JSON" ]; then
            # Parse model IDs from API response and build checklist items
            while IFS= read -r model_id; do
                [ -z "$model_id" ] && continue
                # Mark deepseek or the first model as default
                default="no"
                echo "$model_id" | grep -qi "deepseek" && default="yes"
                MODEL_ITEMS+=("${model_id}||${default}")
            done < <(echo "$MODELS_JSON" | jq -r '.data[].id')
        fi

        # If no models fetched, let user type one manually
        if [ ${#MODEL_ITEMS[@]} -eq 0 ]; then
            echo -n "  Default model name [deepseek-v4-flash]: "; read -r MODEL_NAME
            [ -z "$MODEL_NAME" ] && MODEL_NAME="deepseek-v4-flash"
        else
            echo ""
            MODEL_NAME=$(checklist "Default model" "${MODEL_ITEMS[@]}")
            [ -z "$MODEL_NAME" ] && MODEL_NAME="deepseek-v4-flash"
        fi

        echo ""
        echo -n "  Tool calling? [Y/n]: "; read -r HAS_TOOL
        HAS_TOOL="${HAS_TOOL:-y}"
        [ "$HAS_TOOL" = "y" ] || [ "$HAS_TOOL" = "Y" ] || [ "$HAS_TOOL" = "" ] && TOOL_FLAG=true || TOOL_FLAG=false

        echo -n "  Reasoning mode? [Y/n]: "; read -r HAS_REASON
        HAS_REASON="${HAS_REASON:-y}"
        [ "$HAS_REASON" = "y" ] || [ "$HAS_REASON" = "Y" ] || [ "$HAS_REASON" = "" ] && REASON_FLAG=true || REASON_FLAG=false

        echo -n "  Context window [128000]: "; read -r CTX
        [ -z "$CTX" ] && CTX=128000

        echo -n "  Max output tokens [65536]: "; read -r OUT
        [ -z "$OUT" ] && OUT=65536

        # Build provider JSON with jq
        PROVIDER_JSON=$(mktemp)
        echo '{}' | jq \
          --arg id "$PROVIDER_ID" \
          --arg name "$DISPLAY_NAME" \
          --arg url "$BASE_URL" \
          --arg key "${API_KEY:-}" \
          --arg model "$MODEL_NAME" \
          --arg mname "$DISPLAY_NAME $MODEL_NAME" \
          --argjson tool "$TOOL_FLAG" \
          --argjson reason "$REASON_FLAG" \
          --argjson ctx "$CTX" \
          --argjson out "$OUT" \
          '.provider = {($id): {
            "npm": "@ai-sdk/openai-compatible",
            "name": $name,
            "options": ({baseURL: $url} + if $key != "" then {apiKey: $key} else {} end),
            "models": {($model): {
              "name": $mname,
              "tool_call": $tool,
              "reasoning": $reason,
              "limit": {context: $ctx, output: $out}
            }}
          }}' > "$PROVIDER_JSON"

        # Merge into config
        if command -v jq &>/dev/null; then
            jq -s '.[0] as $e | .[1] as $f |
              ($e + (if $e.provider then {} else {provider:{}} end)) |
              .provider = (.provider + $f.provider)
            ' "$CONFIG_FILE" "$PROVIDER_JSON" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            info "  OK: provider '$PROVIDER_ID' added with model '$MODEL_NAME'"

            # Set model in config
            jq --arg id "$PROVIDER_ID" --arg model "$MODEL_NAME" \
              '.model = ($id + "/" + $model)' \
              "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

            # Set provider in config
            jq --arg id "$PROVIDER_ID" \
              '. + if has("provider") then {provider: (.provider + {})} else {provider: {}} end |
               .provider = (if .provider | has($id) then .provider else .provider + {($id): {}} end)' \
              "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        fi
        rm -f "$PROVIDER_JSON"
    fi
fi

# ── Step 9: Pre-download MCPs ─────────────────────────────────────────
if [ -n "$MCP" ]; then
    title "Pre-downloading MCP packages"
    for mcp in $MCP; do
        echo -n "  ${mcp} ... "
        case "$mcp" in
            searxng) [ "$RUNTIME" = "bun" ] && bunx -y -p one-search-mcp one-search-mcp --version &>/dev/null || npx -y -p one-search-mcp one-search-mcp --version &>/dev/null; info "ok" ;;
            arxiv)   [ "$RUNTIME" = "bun" ] && bunx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version &>/dev/null || npx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version &>/dev/null; info "ok" ;;
        esac
    done
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}  === Installation complete ===${NC}"
echo ""
echo "  Runtime: $RUNTIME"
echo "  Targets: $TARGET"
echo "  Config:  $CONFIG_FILE"
echo "  MCPs:    ${MCP:-none}"
echo ""
if [[ "$MCP" == *"searxng"* ]]; then
    echo -e "${YELLOW}  === Start SearXNG ===${NC}"
    echo "  docker run -d --name searxng -p 8080:8080 searxng/searxng"
    echo ""
fi
echo "  Restart OpenCode. Agents appear as tabs."
echo ""
