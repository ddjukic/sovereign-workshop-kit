#!/usr/bin/env bash
# ============================================================================
# Sovereign Agentic Systems Workshop — Day 1 Validation Setup
# AI Factory Austria, March 17-18, 2026
#
# IDEMPOTENT: Safe to re-run. Updates config and auth in place.
#
# Usage:
#   ./validate-day1.sh --openrouter sk-or-v1-...                 # Required
#   ./validate-day1.sh --openrouter sk-or-... --langdock ld-...   # + EU sovereign agent
#   ./validate-day1.sh --dry-run --openrouter sk-or-...           # Preview only
#   ./validate-day1.sh --restore                                  # Restore personal config
#   ./validate-day1.sh --status                                   # Check current state
#
# The claw-lab/ directory is self-contained for teaching file/folder
# permissions management with OpenClaw:
#   claw-lab/
#     workspace/          ← Agent sandbox (tools.fs.workspaceOnly: true)
#       sample-docs/      ← Input documents (agent can READ)
#       outputs/           ← Agent writes here (agent can WRITE)
#     AGENTS.md           ← Active agent behavior config
#     auth-profiles.json  ← API keys (OpenRouter, Langdock)
#     configs/            ← NOT in workspace — agent CANNOT access
#     skills/             ← User-invocable skill definitions
#     gold-standard/      ← Reference extractions for comparison
#
# Defense-in-Depth Layers (taught in workshop):
#   Layer 1: AGENTS.md routing rules          (advisory, ~90%)
#   Layer 2: tools.deny per agent             (hard enforcement)
#   Layer 3: Docker sandbox (network: none)   (OS-level)
#   Layer 4: Workspace isolation              (filesystem boundary)
#   Layer 5: PostToolUse audit hooks          (detective control)
# ============================================================================

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAW_LAB="$SCRIPT_DIR/claw-lab"
PERSONAL_BACKUP="$HOME/.openclaw-personal-backup"
OPENCLAW_HOME="$HOME/.openclaw"
LOCAL_BIN_SHIM="$HOME/.local/bin/openclaw"
MATERIALS="$SCRIPT_DIR/materials"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
step() { echo -e "\n${BOLD}═══ $1${NC}"; }
info() { echo -e "  ${DIM}$1${NC}"; }
dry()  { echo -e "  ${YELLOW}[DRY]${NC} $1"; }

mask_key() { echo "${1:0:12}...${1: -4}"; }

# ─── Argument Parsing ─────────────────────────────────────────────────────────
OPENROUTER_KEY=""
LANGDOCK_KEY=""
LIGHTNING_KEY=""
DRY_RUN=false
ACTION="setup"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --restore)    ACTION="restore"; shift ;;
        --status)     ACTION="status"; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --openrouter) OPENROUTER_KEY="$2"; shift 2 ;;
        --langdock)   LANGDOCK_KEY="$2"; shift 2 ;;
        --lightning)
            if [[ -z "${2:-}" ]] || [[ "$2" == --* ]]; then
                echo ""
                fail "--lightning requires an API key."
                echo ""
                echo "  Generate one at: https://lightning.ai/docs/litserve/features/authentication?settings=keys"
                echo "  Usage: ./setup.sh --openrouter sk-or-... --lightning lt-..."
                echo ""
                exit 1
            fi
            LIGHTNING_KEY="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./setup.sh --openrouter <key> [--langdock <key>] [--lightning <key>] [--dry-run]"
            echo "       ./setup.sh --restore"
            echo "       ./setup.sh --status"
            echo ""
            echo "Options:"
            echo "  --openrouter <key>   OpenRouter API key (required)"
            echo "  --langdock <key>     Langdock API key (optional, adds EU sovereign agent)"
            echo "  --lightning <key>    Lightning.ai API key (optional, exposes gateway on LAN)"
            echo "                       Generate at: https://lightning.ai/docs/litserve/features/authentication?settings=keys"
            echo "  --dry-run            Preview changes without applying"
            echo "  --restore            Restore personal OpenClaw config from backup"
            echo "  --status             Show current setup state"
            exit 0 ;;
        *) echo -e "  ${RED}✗${NC} Unknown argument: $1"; exit 1 ;;
    esac
done

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                         Restore Mode                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
if [[ "$ACTION" == "restore" ]]; then
    step "Restoring personal OpenClaw configuration"

    # Stop gateway
    openclaw gateway stop 2>/dev/null && ok "Stopped workshop gateway" || true

    # Uninstall npm global openclaw
    npm uninstall -g openclaw 2>/dev/null && ok "Removed npm global openclaw" || true

    # Restore personal config
    if [ -d "$OPENCLAW_HOME" ] && [ ! -d "$PERSONAL_BACKUP" ]; then
        fail "No backup found at $PERSONAL_BACKUP — refusing to delete ~/.openclaw"
        exit 1
    fi

    if [ -d "$PERSONAL_BACKUP" ]; then
        rm -rf "$OPENCLAW_HOME"
        mv "$PERSONAL_BACKUP" "$OPENCLAW_HOME"
        ok "Restored personal config from $PERSONAL_BACKUP"
    else
        warn "No backup found — nothing to restore"
    fi

    # Restore dev clone shim
    if [ -f "${LOCAL_BIN_SHIM}.bak" ]; then
        mv "${LOCAL_BIN_SHIM}.bak" "$LOCAL_BIN_SHIM"
        ok "Restored dev clone shim at $LOCAL_BIN_SHIM"
    elif [ -f "$HOME/openclaw/dist/entry.js" ]; then
        mkdir -p "$HOME/.local/bin"
        cat > "$LOCAL_BIN_SHIM" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
exec node "$HOME/openclaw/dist/entry.js" "$@"
SHIM
        chmod +x "$LOCAL_BIN_SHIM"
        ok "Restored dev clone shim at $LOCAL_BIN_SHIM"
    fi

    echo ""
    ok "Personal configuration restored. Your WhatsApp/Gmail/sessions are intact."
    echo ""
    exit 0
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                         Status Mode                                      ║
# ╚════════════════════════════════════════════════════════════════════════════╝
if [[ "$ACTION" == "status" ]]; then
    step "Current State"
    echo ""

    [ -d "$PERSONAL_BACKUP" ] && ok "Personal backup: $PERSONAL_BACKUP" || info "No personal backup"
    [ -d "$CLAW_LAB" ] && ok "claw-lab/ exists" || info "claw-lab/ not created yet"

    if [ -d "$CLAW_LAB" ]; then
        DOCS=$(ls "$CLAW_LAB/workspace/sample-docs/"*.txt 2>/dev/null | wc -l | tr -d ' ')
        OUTPUTS=$(ls "$CLAW_LAB/workspace/outputs/"*.json 2>/dev/null | wc -l | tr -d ' ')
        info "  Sample docs: $DOCS | Outputs: $OUTPUTS"
    fi

    if command -v openclaw &>/dev/null; then
        ok "openclaw: $(which openclaw) ($(openclaw --version 2>/dev/null || echo '?'))"
    else
        warn "openclaw not in PATH"
    fi

    info "Node.js: $(node --version 2>/dev/null || echo 'not found')"

    if [ -f "$OPENCLAW_HOME/openclaw.json" ]; then
        MODEL=$(grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$OPENCLAW_HOME/openclaw.json" 2>/dev/null | head -1 | sed 's/.*: *"//' | sed 's/"//')
        ok "Config: model=$MODEL"
    else
        info "No openclaw.json"
    fi

    if [ -f "$CLAW_LAB/auth-profiles.json" ]; then
        PROVIDERS=$(grep '"provider"' "$CLAW_LAB/auth-profiles.json" 2>/dev/null | sed 's/.*"provider": *"//' | sed 's/".*//' | tr '\n' ', ' | sed 's/,$//')
        ok "Auth configured: $PROVIDERS"
    else
        warn "No auth-profiles.json (agent won't be able to call models)"
    fi

    GW_STATUS=$(openclaw gateway status 2>&1 | grep "Runtime:" | head -1 || echo "unknown")
    info "Gateway: $GW_STATUS"

    echo ""
    exit 0
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                         Dry Run Mode                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  DRY RUN — no changes will be made                           ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"

    step "Pre-flight"
    echo ""
    echo -e "  ${BOLD}Paths:${NC}"
    echo "    CLAW_LAB:        $CLAW_LAB"
    echo "    OPENCLAW_HOME:   $OPENCLAW_HOME"
    echo "    PERSONAL_BACKUP: $PERSONAL_BACKUP"
    echo ""
    echo -e "  ${BOLD}Keys:${NC}"
    if [ -n "$OPENROUTER_KEY" ]; then
        ok "OpenRouter: $(mask_key "$OPENROUTER_KEY")"
    else
        fail "OpenRouter: NOT PROVIDED (required)"
    fi
    if [ -n "$LANGDOCK_KEY" ]; then
        ok "Langdock: $(mask_key "$LANGDOCK_KEY") (sovereign analyst will be added)"
    else
        info "Langdock: not provided (optional)"
    fi
    if [ -n "$LIGHTNING_KEY" ]; then
        ok "Lightning: $(mask_key "$LIGHTNING_KEY") (gateway bind=lan, trustedProxies=any)"
    else
        info "Lightning: not provided (gateway bind=loopback)"
    fi

    step "Phase 1: Backup"
    if [ -d "$PERSONAL_BACKUP" ]; then
        ok "Backup already exists — would skip"
    elif [ -d "$OPENCLAW_HOME" ]; then
        OCSIZE=$(du -sh "$OPENCLAW_HOME" 2>/dev/null | cut -f1)
        dry "Would move ~/.openclaw/ ($OCSIZE) → backup"
    else
        dry "No ~/.openclaw/ — nothing to back up"
    fi

    step "Phase 2: Installation"
    NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//' || echo "0")
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null && ok "Node.js v$NODE_VERSION" || fail "Need Node 22+"
    if command -v openclaw &>/dev/null; then
        ok "openclaw already installed: $(openclaw --version 2>/dev/null) — would skip reinstall"
    else
        dry "Would run: npm install -g openclaw@latest"
    fi

    step "Phase 3-4: Directory + Materials"
    [ -d "$CLAW_LAB" ] && ok "claw-lab/ exists — would update in place" || dry "Would create claw-lab/"
    DOCS_SRC="$MATERIALS/sample-docs"
    for f in 01-consulting-agreement.txt 02-invoice-techsolutions.txt \
             03-quarterly-financial-report.txt 04-hr-remote-work-policy.txt \
             05-research-paper-abstract.txt; do
        [ -f "$DOCS_SRC/$f" ] && ok "$f" || fail "MISSING: $f"
    done

    step "Phase 5: Config + Auth + Provider"
    dry "Would write ~/.openclaw/openclaw.json (with models.providers.openrouter)"
    dry "Would write ~/.openclaw/agents/assistant/agent/models.json"
    echo "    Agent 1: AlpenTech Assistant (openrouter/step-3.5-flash:free)"
    if [ -n "$LANGDOCK_KEY" ]; then
        echo "    Agent 2: Sovereign Analyst (langdock/claude-sonnet-4-6, sandbox: network:none)"
    fi
    dry "Would write claw-lab/auth-profiles.json"
    echo "    Provider: openrouter → $(mask_key "${OPENROUTER_KEY:-NOT_SET}")"
    [ -n "$LANGDOCK_KEY" ] && echo "    Provider: langdock → $(mask_key "$LANGDOCK_KEY")"

    step "Phase 6: Gateway + Validation"
    dry "Would restart gateway and print tokenized dashboard URL"

    echo ""
    echo -e "  To run for real:  ${BOLD}./validate-day1.sh --openrouter <key>${NC}"
    echo ""
    exit 0
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                    Day 1 Validation — Full Setup                         ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# Require OpenRouter key
if [[ -z "$OPENROUTER_KEY" ]]; then
    echo ""
    fail "OpenRouter API key required."
    echo ""
    echo "  Usage: ./validate-day1.sh --openrouter sk-or-v1-..."
    echo "  Get a free key at: https://openrouter.ai/keys"
    echo ""
    echo "  Optional — add EU sovereign agent:"
    echo "  ./validate-day1.sh --openrouter sk-or-... --langdock ld-..."
    echo ""
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Sovereign Agentic Systems — Day 1 Validation Setup          ║"
echo "║  AI Factory Austria, March 2026                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  OpenRouter key: $(mask_key "$OPENROUTER_KEY")"
[ -n "$LANGDOCK_KEY" ] && echo "  Langdock key:   $(mask_key "$LANGDOCK_KEY") (sovereign analyst enabled)"
[ -n "$LIGHTNING_KEY" ] && echo "  Lightning key:  $(mask_key "$LIGHTNING_KEY") (LAN gateway mode)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 1/7: Backing up personal configuration"
# ═══════════════════════════════════════════════════════════════════════════════

if [ -d "$PERSONAL_BACKUP" ]; then
    ok "Backup already exists at $PERSONAL_BACKUP (safe)"
elif [ -d "$OPENCLAW_HOME" ]; then
    mv "$OPENCLAW_HOME" "$PERSONAL_BACKUP"
    ok "Moved ~/.openclaw/ → ~/.openclaw-personal-backup/"
    info "Contains: WhatsApp creds, Gmail tokens, sessions, personal config"
else
    ok "No ~/.openclaw/ found — nothing to back up"
fi

# Stash dev clone shim if it exists and hasn't been stashed
if [ -f "$LOCAL_BIN_SHIM" ] && [ ! -f "${LOCAL_BIN_SHIM}.bak" ]; then
    mv "$LOCAL_BIN_SHIM" "${LOCAL_BIN_SHIM}.bak"
    ok "Stashed dev clone shim → ${LOCAL_BIN_SHIM}.bak"
elif [ -f "${LOCAL_BIN_SHIM}.bak" ]; then
    ok "Dev clone shim already stashed"
fi

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 2/7: OpenClaw installation"
# ═══════════════════════════════════════════════════════════════════════════════

# Verify Node.js 22+
NODE_VERSION=$(node --version 2>/dev/null | sed 's/^v//' || echo "0")
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)

if [ "$NODE_MAJOR" -ge 22 ] 2>/dev/null; then
    ok "Node.js v$NODE_VERSION (22+ required)"
else
    fail "Node.js 22+ required, found v$NODE_VERSION"
    echo "    Run: nvm install 22 && nvm use 22"
    exit 1
fi

# Install openclaw if not present or update if present
OPENCLAW_BIN=$(which openclaw 2>/dev/null || echo "")
if [ -n "$OPENCLAW_BIN" ] && [[ "$OPENCLAW_BIN" != *".local/bin"* ]]; then
    # Already installed via npm (not the dev shim)
    CURRENT=$(openclaw --version 2>/dev/null || echo "unknown")
    ok "OpenClaw already installed: $CURRENT"
    info "Updating to latest..."
    npm install -g openclaw@latest 2>/dev/null
    ok "Updated to $(openclaw --version 2>/dev/null)"
else
    # Remove stale npm global if any
    npm uninstall -g openclaw 2>/dev/null || true
    info "Installing openclaw@latest via npm..."
    npm install -g openclaw@latest
    ok "OpenClaw $(openclaw --version 2>/dev/null) installed"
fi
info "Binary: $(which openclaw)"

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 3/7: Creating claw-lab/ directory structure"
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p "$CLAW_LAB/workspace/sample-docs"
mkdir -p "$CLAW_LAB/workspace/outputs"
mkdir -p "$CLAW_LAB/configs/workspace-agents"
mkdir -p "$CLAW_LAB/configs/hooks"
mkdir -p "$CLAW_LAB/skills"
mkdir -p "$CLAW_LAB/gold-standard"

ok "claw-lab/ structure ready (created or verified)"

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 4/7: Copying workshop materials"
# ═══════════════════════════════════════════════════════════════════════════════

# Sample documents
DOCS_SRC="$MATERIALS/sample-docs"
DOCS_COPIED=0
for f in 01-consulting-agreement.txt 02-invoice-techsolutions.txt \
         03-quarterly-financial-report.txt 04-hr-remote-work-policy.txt \
         05-research-paper-abstract.txt extraction-schema.json; do
    if [ -f "$DOCS_SRC/$f" ]; then
        cp "$DOCS_SRC/$f" "$CLAW_LAB/workspace/sample-docs/$f"
        DOCS_COPIED=$((DOCS_COPIED + 1))
    else
        warn "Missing: $f"
    fi
done
ok "Copied $DOCS_COPIED sample documents"

# Gold standard extractions
if [ -d "$DOCS_SRC/gold-standard" ]; then
    cp "$DOCS_SRC/gold-standard/"*.json "$CLAW_LAB/gold-standard/" 2>/dev/null
    GS_COUNT=$(ls "$CLAW_LAB/gold-standard/"*.json 2>/dev/null | wc -l | tr -d ' ')
    ok "Copied $GS_COUNT gold-standard extractions"
fi

# AGENTS.md
WK="$MATERIALS/workshop-kit"
cp "$WK/AGENTS-default.md" "$CLAW_LAB/AGENTS.md"
cp "$WK/AGENTS-default.md" "$CLAW_LAB/configs/AGENTS-default.md"
cp "$WK/AGENTS-mission2.md" "$CLAW_LAB/configs/AGENTS-mission2.md"
ok "AGENTS.md installed (default for Mission 0/1)"

# Mission configs (rewrite paths)
sed "s|~/.openclaw-workshop/workspace|$CLAW_LAB/workspace|g; s|~/.openclaw-workshop|$CLAW_LAB|g" \
    "$WK/openclaw-mission0.json" > "$CLAW_LAB/configs/openclaw-mission0.json"
sed "s|~/.openclaw-workshop/workspace|$CLAW_LAB/workspace|g; s|~/.openclaw-workshop|$CLAW_LAB|g" \
    "$WK/openclaw-mission2.json" > "$CLAW_LAB/configs/openclaw-mission2.json"
cp "$MATERIALS/templates/openclaw.json" "$CLAW_LAB/configs/openclaw-sovereign-team.json5"
ok "Mission configs copied with correct paths"

# Per-agent workspace AGENTS.md (sovereign team)
TEMPLATES="$MATERIALS/templates"
WS_AGENTS_COPIED=0
for ws_dir in "$TEMPLATES"/workspace-*/; do
    ws_name=$(basename "$ws_dir")
    if [ -f "$ws_dir/AGENTS.md" ]; then
        cp "$ws_dir/AGENTS.md" "$CLAW_LAB/configs/workspace-agents/${ws_name}.md"
        WS_AGENTS_COPIED=$((WS_AGENTS_COPIED + 1))
    fi
done
ok "Copied $WS_AGENTS_COPIED workspace AGENTS.md files"

# Audit hook
[ -f "$TEMPLATES/hooks/audit-hook.py" ] && \
    cp "$TEMPLATES/hooks/audit-hook.py" "$CLAW_LAB/configs/hooks/audit-hook.py" && \
    ok "Copied audit-hook.py" || true

# Skills
SKILLS_SRC="$MATERIALS/templates/skills"
SKILLS_COPIED=0
for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
        mkdir -p "$CLAW_LAB/skills/$skill_name"
        cp "$skill_dir/SKILL.md" "$CLAW_LAB/skills/$skill_name/SKILL.md"
        SKILLS_COPIED=$((SKILLS_COPIED + 1))
    fi
done
ok "Copied $SKILLS_COPIED skills"

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 5/7: Writing configuration + authentication"
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p "$OPENCLAW_HOME"

# ── Build openclaw.json ───────────────────────────────────────────────────────
# Base config: single agent on OpenRouter free model
if [ -n "$LIGHTNING_KEY" ]; then
    GW_BLOCK=$(cat <<GWEOF
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "controlUi": {
      "allowInsecureAuth": true,
      "allowedOrigins": ["*"]
    },
    "auth": { "mode": "token", "token": "$LIGHTNING_KEY" },
    "trustedProxies": ["any", "*"]
  },
GWEOF
)
else
    GW_BLOCK=$(cat <<GWEOF
  "gateway": {
    "mode": "local",
    "bind": "loopback"
  },
GWEOF
)
fi

if [ -n "$LANGDOCK_KEY" ]; then
    # Two agents: OpenRouter assistant + Langdock sovereign analyst
    cat > "$OPENCLAW_HOME/openclaw.json" << OCJSON
{
  "env": {
    "OPENROUTER_API_KEY": "$OPENROUTER_KEY"
  },
$GW_BLOCK
  "models": {
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-completions",
        "apiKey": "$OPENROUTER_KEY",
        "models": [
          {
            "id": "stepfun/step-3.5-flash:free",
            "name": "StepFun Step 3.5 Flash (free)",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 256000,
            "maxTokens": 8192
          }
        ]
      },
      "langdock": {
        "baseUrl": "https://api.langdock.com/v1",
        "apiKey": "$LANGDOCK_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "claude-sonnet-4-6",
            "name": "Claude Sonnet 4.6 (Langdock EU)",
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "verboseDefault": "on"
    },
    "list": [
      {
        "id": "assistant",
        "default": true,
        "name": "AlpenTech Assistant",
        "model": "openrouter/stepfun/step-3.5-flash:free",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$CLAW_LAB",
        "identity": {
          "name": "AlpenTech AI",
          "emoji": "shield"
        },
        "tools": {
          "profile": "coding"
        }
      },
      {
        "id": "sovereign-analyst",
        "name": "AlpenTech Sovereign Analyst",
        "model": "langdock/claude-sonnet-4-6",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$CLAW_LAB",
        "identity": {
          "name": "Sovereign Analyst",
          "emoji": "lock"
        },
        "tools": {
          "profile": "coding"
        },
        "sandbox": {
          "mode": "all",
          "docker": {
            "network": "none"
          }
        }
      }
    ]
  },
  "tools": {
    "fs": {
      "workspaceOnly": true
    }
  }
}
OCJSON
    ok "Wrote openclaw.json (2 agents: OpenRouter + Langdock EU)"
    info "  Agent 1: AlpenTech Assistant → openrouter/step-3.5-flash:free"
    info "  Agent 2: Sovereign Analyst → langdock/claude-sonnet-4-6 (sandbox: network:none)"
else
    # Single agent: OpenRouter only
    cat > "$OPENCLAW_HOME/openclaw.json" << OCJSON
{
  "env": {
    "OPENROUTER_API_KEY": "$OPENROUTER_KEY"
  },
$GW_BLOCK
  "models": {
    "providers": {
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-completions",
        "apiKey": "$OPENROUTER_KEY",
        "models": [
          {
            "id": "stepfun/step-3.5-flash:free",
            "name": "StepFun Step 3.5 Flash (free)",
            "reasoning": true,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 256000,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "verboseDefault": "on"
    },
    "list": [
      {
        "id": "assistant",
        "default": true,
        "name": "AlpenTech Assistant",
        "model": "openrouter/stepfun/step-3.5-flash:free",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$CLAW_LAB",
        "identity": {
          "name": "AlpenTech AI",
          "emoji": "shield"
        },
        "tools": {
          "profile": "coding"
        }
      }
    ]
  },
  "tools": {
    "fs": {
      "workspaceOnly": true
    }
  }
}
OCJSON
    ok "Wrote openclaw.json (1 agent: OpenRouter)"
    info "  Agent: AlpenTech Assistant → openrouter/step-3.5-flash:free"
fi
info "  Workspace: $CLAW_LAB/workspace/"
info "  tools.fs.workspaceOnly: true"
if [ -n "$LIGHTNING_KEY" ]; then
    ok "Gateway configured for Lightning.ai (bind=lan, trustedProxies=any)"
fi

# ── Write agent-level models.json for direct OpenRouter routing ──────────────
# OpenClaw resolves models from ~/.openclaw/agents/<id>/agent/models.json
AGENT_MODELS_DIR="$OPENCLAW_HOME/agents/assistant/agent"
mkdir -p "$AGENT_MODELS_DIR"
cat > "$AGENT_MODELS_DIR/models.json" << MODEOF
{
  "providers": {
    "openrouter": {
      "baseUrl": "https://openrouter.ai/api/v1",
      "api": "openai-completions",
      "apiKey": "$OPENROUTER_KEY",
      "models": [
        {
          "id": "stepfun/step-3.5-flash:free",
          "name": "StepFun Step 3.5 Flash (free)",
          "reasoning": true,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 256000,
          "maxTokens": 8192
        },
        {
          "id": "nvidia/nemotron-3-super-120b-a12b:free",
          "name": "NVIDIA Nemotron 3 Super (free)",
          "reasoning": false,
          "input": ["text"],
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 131072,
          "maxTokens": 8192
        }
      ]
    }
  }
}
MODEOF
ok "Wrote agent-level models.json (OpenRouter provider + model catalog)"

# ── Write auth-profiles.json to agentDir (claw-lab/) ─────────────────────────
AUTH_PROFILES="$CLAW_LAB/auth-profiles.json"

if [ -n "$LANGDOCK_KEY" ]; then
    cat > "$AUTH_PROFILES" << AUTHEOF
{
  "version": 1,
  "profiles": {
    "openrouter:default": {
      "type": "token",
      "provider": "openrouter",
      "token": "$OPENROUTER_KEY"
    },
    "langdock:default": {
      "type": "token",
      "provider": "langdock",
      "token": "$LANGDOCK_KEY"
    }
  },
  "lastGood": {
    "openrouter": "openrouter:default",
    "langdock": "langdock:default"
  }
}
AUTHEOF
    ok "Wrote auth-profiles.json (openrouter + langdock)"
else
    cat > "$AUTH_PROFILES" << AUTHEOF
{
  "version": 1,
  "profiles": {
    "openrouter:default": {
      "type": "token",
      "provider": "openrouter",
      "token": "$OPENROUTER_KEY"
    }
  },
  "lastGood": {
    "openrouter": "openrouter:default"
  }
}
AUTHEOF
    ok "Wrote auth-profiles.json (openrouter)"
fi
info "  Auth store: $AUTH_PROFILES"

# Copy skills to openclaw state dir
cp -r "$CLAW_LAB/skills" "$OPENCLAW_HOME/skills" 2>/dev/null || true
ok "Synced skills to ~/.openclaw/skills/"

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 6/7: Gateway"
# ═══════════════════════════════════════════════════════════════════════════════

# Stop any running gateway (old or new)
openclaw gateway stop 2>/dev/null || true
if command -v launchctl &>/dev/null; then
    # macOS
    launchctl bootout "gui/$(id -u)/com.clawdbot.gateway" 2>/dev/null || true
    launchctl bootout "gui/$(id -u)/ai.openclaw.gateway" 2>/dev/null || true
    rm -f ~/Library/LaunchAgents/com.clawdbot.gateway.plist 2>/dev/null
fi
sleep 1

# Try daemon install first (macOS launchd or Linux systemd)
GW_DAEMON=false
if openclaw gateway install --force 2>/dev/null; then
    ok "Gateway daemon installed"
    if openclaw gateway start 2>/dev/null; then
        ok "Gateway started (daemon)"
        GW_DAEMON=true
    fi
fi

# Fallback: start gateway in background if daemon failed (common on WSL/Linux without systemd)
if [ "$GW_DAEMON" = false ]; then
    warn "Daemon install not available (WSL/Linux without systemd)"
    info "Starting gateway in background..."
    nohup openclaw gateway --port 18789 > "$OPENCLAW_HOME/logs/gateway.log" 2>&1 &
    GW_PID=$!
    sleep 3
    if kill -0 "$GW_PID" 2>/dev/null; then
        ok "Gateway started in background (PID $GW_PID)"
        info "To stop later: kill $GW_PID"
    else
        warn "Gateway failed to start — run manually: openclaw gateway"
    fi
fi

# Wait for gateway to initialize and write its auth token
sleep 2

# Clean up OpenClaw auto-scaffolded workspace files that confuse the agent
# These inject a generic "personal assistant" personality into context, overriding our AGENTS.md
for bootstrap_file in AGENTS.md SOUL.md TOOLS.md IDENTITY.md USER.md HEARTBEAT.md BOOTSTRAP.md; do
    rm -f "$CLAW_LAB/workspace/$bootstrap_file" 2>/dev/null
done
rm -rf "$CLAW_LAB/workspace/.git" "$CLAW_LAB/workspace/.openclaw" "$CLAW_LAB/workspace/memory" 2>/dev/null
ok "Cleaned OpenClaw bootstrap files from workspace"

# Read the gateway token from config (gateway auto-generates on first start)
GW_TOKEN=""
if [ -f "$OPENCLAW_HOME/openclaw.json" ]; then
    GW_TOKEN=$(grep '"token"' "$OPENCLAW_HOME/openclaw.json" 2>/dev/null | grep -v '"mode"' | head -1 | sed 's/.*"token"[[:space:]]*:[[:space:]]*"//' | sed 's/".*//')
fi

if [ -n "$GW_TOKEN" ]; then
    ok "Gateway auth token: ${GW_TOKEN:0:12}..."
else
    warn "Could not read gateway token — check ~/.openclaw/openclaw.json"
fi

# ═══════════════════════════════════════════════════════════════════════════════
step "Phase 7/7: Validation"
# ═══════════════════════════════════════════════════════════════════════════════

ERRORS=0

# Binary
command -v openclaw &>/dev/null && ok "openclaw binary: $(which openclaw)" || { fail "openclaw not in PATH"; ERRORS=$((ERRORS + 1)); }

# Version
VER=$(openclaw --version 2>/dev/null || echo "FAIL")
[ "$VER" != "FAIL" ] && ok "Version: $VER" || { fail "Version check failed"; ERRORS=$((ERRORS + 1)); }

# Config
[ -f "$OPENCLAW_HOME/openclaw.json" ] && ok "Config exists" || { fail "Config missing"; ERRORS=$((ERRORS + 1)); }

# Sample docs
DOC_COUNT=$(ls "$CLAW_LAB/workspace/sample-docs/"*.txt 2>/dev/null | wc -l | tr -d ' ')
[ "$DOC_COUNT" -ge 5 ] && ok "$DOC_COUNT sample documents in workspace" || { fail "Expected 5+ docs, found $DOC_COUNT"; ERRORS=$((ERRORS + 1)); }

# Schema
[ -f "$CLAW_LAB/workspace/sample-docs/extraction-schema.json" ] && ok "Extraction schema present" || { fail "Schema missing"; ERRORS=$((ERRORS + 1)); }

# AGENTS.md
[ -f "$CLAW_LAB/AGENTS.md" ] && ok "AGENTS.md present" || { fail "AGENTS.md missing"; ERRORS=$((ERRORS + 1)); }

# Auth
[ -f "$CLAW_LAB/auth-profiles.json" ] && ok "auth-profiles.json present" || { fail "Auth missing"; ERRORS=$((ERRORS + 1)); }

# Skills
SKILL_COUNT=$(find "$CLAW_LAB/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$SKILL_COUNT" -ge 5 ] && ok "$SKILL_COUNT skills installed" || warn "Only $SKILL_COUNT skills (expected 7)"

# Outputs writable
touch "$CLAW_LAB/workspace/outputs/.write-test" 2>/dev/null && \
    rm "$CLAW_LAB/workspace/outputs/.write-test" && \
    ok "Outputs directory writable" || { fail "Outputs not writable"; ERRORS=$((ERRORS + 1)); }

# Gold standard
GS_COUNT=$(ls "$CLAW_LAB/gold-standard/"*.json 2>/dev/null | wc -l | tr -d ' ')
[ "$GS_COUNT" -ge 5 ] && ok "$GS_COUNT gold-standard references" || warn "Only $GS_COUNT gold-standard files"

# Gateway running
GW_RUNTIME=$(openclaw gateway status 2>&1 | grep "Runtime:" | head -1 || echo "")
if echo "$GW_RUNTIME" | grep -q "running"; then
    ok "Gateway running"
else
    warn "Gateway may not be running — check: openclaw gateway status"
fi

# ─── Results ──────────────────────────────────────────────────────────────────
echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo -e "╔════════════════════════════════════════════════════════════════╗"
    echo -e "║  ${GREEN}ALL CHECKS PASSED${NC}                                           ║"
    echo -e "╚════════════════════════════════════════════════════════════════╝"
else
    echo -e "╔════════════════════════════════════════════════════════════════╗"
    echo -e "║  ${RED}$ERRORS CHECK(S) FAILED${NC} — review errors above                     ║"
    echo -e "╚════════════════════════════════════════════════════════════════╝"
fi

# ─── Dashboard URL ────────────────────────────────────────────────────────────
echo ""
echo -e "  ══════════════════════════════════════════════════════════════"
echo -e "  ${BOLD}OPEN YOUR DASHBOARD:${NC}"
echo -e "  ══════════════════════════════════════════════════════════════"
echo ""
if [ -n "$LIGHTNING_KEY" ]; then
    echo -e "  ${BOLD}Local:${NC}  http://127.0.0.1:18789/?token=${LIGHTNING_KEY}"
    echo ""
    echo -e "  ${BOLD}Lightning.ai:${NC} Open port 18789 in your Studio, then visit:"
    echo -e "  ${BOLD}https://<your-studio>.studios.lightning.ai:18789/?token=${LIGHTNING_KEY}${NC}"
    echo ""
    echo -e "  ${DIM}To expose the port: click the plug icon in the Studio sidebar → Add Port → 18789${NC}"
elif [ -n "$GW_TOKEN" ]; then
    echo -e "  ${BOLD}http://127.0.0.1:18789/?token=${GW_TOKEN}${NC}"
else
    echo -e "  ${BOLD}http://127.0.0.1:18789/${NC}"
    echo "  (paste gateway token from: grep token ~/.openclaw/openclaw.json)"
fi
echo ""
echo -e "  ══════════════════════════════════════════════════════════════"
echo -e "  ${BOLD}WORKSHOP MISSIONS:${NC}"
echo -e "  ══════════════════════════════════════════════════════════════"
echo ""
echo "  Mission 0 — smoke test:"
echo "    \"Hello, what model are you running on?\""
echo ""
echo "  Mission 1 — first extraction:"
echo "    \"Read 01-consulting-agreement.txt and extract all parties,"
echo "     dates, and key obligations. Write result to outputs/.\""
echo ""
echo "  Mission 2 — swap to auditor config:"
echo -e "    ${BOLD}cp $CLAW_LAB/configs/AGENTS-mission2.md $CLAW_LAB/AGENTS.md${NC}"
echo -e "    ${BOLD}openclaw gateway restart${NC}"
echo ""
echo -e "  ══════════════════════════════════════════════════════════════"
echo -e "  ${BOLD}WORKSPACE ISOLATION:${NC}"
echo -e "  ══════════════════════════════════════════════════════════════"
echo ""
echo "  claw-lab/"
echo "    AGENTS.md                ← Agent behavior (agentDir)"
echo "    auth-profiles.json       ← API keys (agentDir)"
echo "    workspace/               ← SANDBOX (workspaceOnly: true)"
echo "      sample-docs/          ← Agent can READ"
echo "      outputs/              ← Agent can WRITE"
echo "    configs/                 ← OUTSIDE workspace — CANNOT access"
echo "    gold-standard/           ← OUTSIDE workspace — CANNOT access"
echo ""
echo -e "  ══════════════════════════════════════════════════════════════"
echo -e "  RESTORE: ${BOLD}./validate-day1.sh --restore${NC}"
echo -e "  ══════════════════════════════════════════════════════════════"
echo ""
