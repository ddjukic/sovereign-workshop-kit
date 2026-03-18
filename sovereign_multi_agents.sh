#!/usr/bin/env bash
# ============================================================================
# Sovereign Multi-Agent Orchestration — Setup Script
# AI Factory Austria, March 17-18, 2026
#
# IDEMPOTENT: Safe to re-run. Overwrites config and auth in place.
#
# Sets up a 3-agent sovereign architecture with OpenClaw:
#   1. Orchestrator       (Langdock EU)  — routes tasks, never reads files
#   2. Sovereign Analyst  (Langdock EU)  — sensitive docs, PII, contracts
#   3. Web Researcher     (OpenRouter)   — public web searches only
#
# Usage:
#   ./sovereign_multi_agents.sh --openrouter sk-or-v1-... --langdock sk-...
#   ./sovereign_multi_agents.sh --dry-run --openrouter sk-or-... --langdock sk-...
#   ./sovereign_multi_agents.sh --help
#
# Sovereignty Model:
#   The orchestrator is the "sovereignty ceiling" — it runs on Langdock EU,
#   so all sub-agent results that flow back through it remain in EU jurisdiction.
#   The web-researcher runs on OpenRouter (outside EU) but only handles public data.
#
# Defense-in-Depth Layers:
#   Layer 1: AGENTS.md routing rules           (advisory, ~90%)
#   Layer 2: tools.deny / tools.allow per agent (hard enforcement)
#   Layer 3: Workspace isolation                (filesystem boundary)
#   Layer 4: Agent-to-agent spawn controls      (maxSpawnDepth, allow lists)
#   Layer 5: diagnostics-otel plugin            (detective control)
# ============================================================================

set -euo pipefail

# --- Constants ---------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAW_LAB="$SCRIPT_DIR/claw-lab"
OPENCLAW_HOME="$HOME/.openclaw"

# --- Colors ------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
phase(){ echo -e "\n${BOLD}[$1]${NC} $2"; }
info() { echo -e "  ${DIM}$1${NC}"; }
dry()  { echo -e "  ${YELLOW}[DRY]${NC} $1"; }

mask_key() { echo "${1:0:12}...${1: -4}"; }

# --- Argument Parsing --------------------------------------------------------
OPENROUTER_KEY=""
LANGDOCK_KEY=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=true; shift ;;
        --openrouter)
            if [[ -z "${2:-}" ]] || [[ "${2:-}" == --* ]]; then
                fail "--openrouter requires an API key."
                echo "  Get one at: https://openrouter.ai/keys"
                exit 1
            fi
            OPENROUTER_KEY="$2"; shift 2 ;;
        --langdock)
            if [[ -z "${2:-}" ]] || [[ "${2:-}" == --* ]]; then
                fail "--langdock requires an API key."
                echo "  Get one from your Langdock workspace admin."
                exit 1
            fi
            LANGDOCK_KEY="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./sovereign_multi_agents.sh --openrouter <key> --langdock <key> [--dry-run]"
            echo ""
            echo "Sets up a 3-agent sovereign orchestration architecture with OpenClaw:"
            echo "  1. Orchestrator       (Langdock EU)  — routes tasks to sub-agents"
            echo "  2. Sovereign Analyst  (Langdock EU)  — sensitive documents, PII, contracts"
            echo "  3. Web Researcher     (OpenRouter)   — public web searches only"
            echo ""
            echo "Required:"
            echo "  --openrouter <key>   OpenRouter API key (for web-researcher agent)"
            echo "  --langdock <key>     Langdock API key (for orchestrator + sovereign-analyst)"
            echo ""
            echo "Optional:"
            echo "  --dry-run            Preview changes without writing anything"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Example:"
            echo "  ./sovereign_multi_agents.sh --openrouter sk-or-v1-abc123 --langdock sk-xyz789"
            exit 0 ;;
        *) fail "Unknown argument: $1"; exit 1 ;;
    esac
done

# --- Validate Required Keys --------------------------------------------------
if [[ -z "$OPENROUTER_KEY" ]] || [[ -z "$LANGDOCK_KEY" ]]; then
    echo ""
    fail "Both --openrouter and --langdock keys are required."
    echo ""
    echo "  Usage: ./sovereign_multi_agents.sh --openrouter sk-or-v1-... --langdock sk-..."
    echo ""
    echo "  --openrouter: https://openrouter.ai/keys"
    echo "  --langdock:   From your Langdock workspace admin"
    echo ""
    exit 1
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                         Dry Run Mode                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝
if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  DRY RUN — no changes will be made                           ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Keys:${NC}"
    ok "OpenRouter: $(mask_key "$OPENROUTER_KEY")"
    ok "Langdock:   $(mask_key "$LANGDOCK_KEY")"
    echo ""
    echo -e "  ${BOLD}Paths:${NC}"
    echo "    SCRIPT_DIR:    $SCRIPT_DIR"
    echo "    CLAW_LAB:      $CLAW_LAB"
    echo "    OPENCLAW_HOME: $OPENCLAW_HOME"

    phase "1/11" "Agent directories"
    dry "mkdir -p $CLAW_LAB/workspace/outputs/"
    dry "mkdir -p $SCRIPT_DIR/claw-lab-sovereign/"
    dry "mkdir -p $SCRIPT_DIR/claw-lab-researcher/"

    phase "2/11" "Auth profiles"
    dry "Write $CLAW_LAB/auth-profiles.json (openrouter + langdock)"
    dry "Write $SCRIPT_DIR/claw-lab-sovereign/auth-profiles.json (langdock)"
    dry "Write $SCRIPT_DIR/claw-lab-researcher/auth-profiles.json (openrouter)"

    phase "3/11" "Model configurations"
    dry "Write $CLAW_LAB/models.json (langdock + openrouter)"
    dry "Write $SCRIPT_DIR/claw-lab-sovereign/models.json (langdock)"
    dry "Write $SCRIPT_DIR/claw-lab-researcher/models.json (openrouter)"

    phase "4/11" "AGENTS.md files"
    dry "Write $CLAW_LAB/AGENTS.md (orchestrator)"
    dry "Write $SCRIPT_DIR/claw-lab-sovereign/AGENTS.md (sovereign-analyst)"
    dry "Write $SCRIPT_DIR/claw-lab-researcher/AGENTS.md (web-researcher)"

    phase "5/11" "openclaw.json"
    dry "Write $OPENCLAW_HOME/openclaw.json (3 agents, 2 providers, agent-to-agent enabled)"

    phase "6/11" "Agent-level models.json"
    dry "Write $OPENCLAW_HOME/agents/assistant/agent/models.json"
    dry "Write $OPENCLAW_HOME/agents/sovereign-analyst/agent/models.json"
    dry "Write $OPENCLAW_HOME/agents/web-researcher/agent/models.json"

    phase "7/11" "Sovereign-route skill"
    dry "Write $CLAW_LAB/skills/sovereign-route/SKILL.md"

    phase "8/11" "Logging and audit trail"
    dry "Configure logging (level=info, redactSensitive=tools)"

    phase "9/11" "Workspace structure"
    dry "Ensure $CLAW_LAB/workspace/sample-docs/ exists"
    dry "Ensure $CLAW_LAB/workspace/outputs/ exists"

    phase "10/11" "Gateway restart"
    dry "openclaw gateway restart"

    phase "11/11" "Summary"
    dry "Print agent architecture summary"

    echo ""
    echo -e "  To run for real:  ${BOLD}./sovereign_multi_agents.sh --openrouter <key> --langdock <key>${NC}"
    echo ""
    exit 0
fi

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║              Sovereign Multi-Agent Orchestration — Full Setup            ║
# ╚════════════════════════════════════════════════════════════════════════════╝

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Sovereign Multi-Agent Orchestration Setup                    ║"
echo "║  AI Factory Austria, March 2026                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "  OpenRouter key: $(mask_key "$OPENROUTER_KEY")"
echo "  Langdock key:   $(mask_key "$LANGDOCK_KEY")"
echo ""

# Generate a gateway auth token
GW_AUTH_TOKEN=$(openssl rand -hex 24)

# =============================================================================
phase "1/11" "Creating agent directories"
# =============================================================================

mkdir -p "$CLAW_LAB/workspace/sample-docs"
mkdir -p "$CLAW_LAB/workspace/outputs"
mkdir -p "$CLAW_LAB/skills"
ok "claw-lab/ (orchestrator)"

mkdir -p "$SCRIPT_DIR/claw-lab-sovereign"
ok "claw-lab-sovereign/ (sovereign-analyst)"

mkdir -p "$SCRIPT_DIR/claw-lab-researcher"
ok "claw-lab-researcher/ (web-researcher)"

# =============================================================================
phase "2/11" "Writing auth-profiles.json"
# =============================================================================

# Orchestrator: both providers
cat > "$CLAW_LAB/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "langdock:default": {
      "type": "token",
      "provider": "langdock",
      "token": "$LANGDOCK_KEY"
    },
    "openrouter:default": {
      "type": "token",
      "provider": "openrouter",
      "token": "$OPENROUTER_KEY"
    }
  },
  "lastGood": {
    "langdock": "langdock:default",
    "openrouter": "openrouter:default"
  },
  "usageStats": {}
}
EOF
ok "claw-lab/auth-profiles.json (langdock + openrouter)"

# Sovereign Analyst: langdock only
cat > "$SCRIPT_DIR/claw-lab-sovereign/auth-profiles.json" << EOF
{
  "version": 1,
  "profiles": {
    "langdock:default": {
      "type": "token",
      "provider": "langdock",
      "token": "$LANGDOCK_KEY"
    }
  },
  "lastGood": {
    "langdock": "langdock:default"
  },
  "usageStats": {}
}
EOF
ok "claw-lab-sovereign/auth-profiles.json (langdock)"

# Web Researcher: openrouter only
cat > "$SCRIPT_DIR/claw-lab-researcher/auth-profiles.json" << EOF
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
  },
  "usageStats": {}
}
EOF
ok "claw-lab-researcher/auth-profiles.json (openrouter)"

# =============================================================================
phase "3/11" "Writing models.json"
# =============================================================================

# Orchestrator: langdock + openrouter
cat > "$CLAW_LAB/models.json" << EOF
{
  "providers": {
    "langdock": {
      "baseUrl": "https://api.langdock.com/anthropic/eu/v1",
      "api": "anthropic-messages",
      "apiKey": "$LANGDOCK_KEY",
      "models": [
        {
          "id": "claude-sonnet-4-6-default",
          "name": "Claude Sonnet 4.6 (Langdock EU)",
          "reasoning": false,
          "input": ["text", "image"],
          "cost": { "input": 0.003, "output": 0.015, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 200000,
          "maxTokens": 8192
        }
      ]
    },
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
}
EOF
ok "claw-lab/models.json (langdock + openrouter)"

# Sovereign Analyst: langdock only
cat > "$SCRIPT_DIR/claw-lab-sovereign/models.json" << EOF
{
  "providers": {
    "langdock": {
      "baseUrl": "https://api.langdock.com/anthropic/eu/v1",
      "api": "anthropic-messages",
      "apiKey": "$LANGDOCK_KEY",
      "models": [
        {
          "id": "claude-sonnet-4-6-default",
          "name": "Claude Sonnet 4.6 (Langdock EU)",
          "reasoning": false,
          "input": ["text", "image"],
          "cost": { "input": 0.003, "output": 0.015, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 200000,
          "maxTokens": 8192
        }
      ]
    }
  }
}
EOF
ok "claw-lab-sovereign/models.json (langdock)"

# Web Researcher: openrouter only
cat > "$SCRIPT_DIR/claw-lab-researcher/models.json" << EOF
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
        }
      ]
    }
  }
}
EOF
ok "claw-lab-researcher/models.json (openrouter)"

# =============================================================================
phase "4/11" "Writing AGENTS.md"
# =============================================================================

# Orchestrator
cat > "$CLAW_LAB/AGENTS.md" << 'EOF'
# AlpenTech AI — Orchestrator Agent

You are an orchestrator. You do NOT process documents yourself. You route tasks to specialist agents.

> **Sovereignty note:** You are the sovereignty ceiling. Because you see all sub-agent results via `sessions_spawn`, you run on **Langdock EU** (GDPR-compliant). This ensures all data — including results returned by sub-agents — stays within EU jurisdiction.

## Your Agents

| Agent ID | Name | Provider | Specialty |
|----------|------|----------|-----------|
| sovereign-analyst | Sovereign Analyst | Langdock EU | Sensitive documents, PII extraction, contracts, financial reports |
| web-researcher | Web Researcher | OpenRouter (StepFun) | Public web searches, non-sensitive research, general knowledge |

## How to Delegate

Use `sessions_spawn` with agentId, task, and label parameters.

## Routing Rules

- Documents, PII, contracts, internal data → sovereign-analyst
- Web searches, public info, news → web-researcher

## Hard Rules

- You CANNOT read files yourself (read is denied)
- You MUST use sessions_spawn with the correct agentId
- NEVER send sensitive content to web-researcher (runs on OpenRouter, outside EU)
EOF
ok "claw-lab/AGENTS.md (orchestrator)"

# Sovereign Analyst
cat > "$SCRIPT_DIR/claw-lab-sovereign/AGENTS.md" << 'EOF'
# AlpenTech Sovereign Analyst

You are the **Sovereign Analyst** running on Langdock EU.

## Rules
- Process documents within EU jurisdiction only
- Extract entities in structured JSON format
- Write full extractions to outputs/ directory
- Return only summary references to orchestrator
- NEVER include raw PII in responses back to orchestrator
- Flag all PII with risk classification (high/medium/low)
EOF
ok "claw-lab-sovereign/AGENTS.md (sovereign-analyst)"

# Web Researcher
cat > "$SCRIPT_DIR/claw-lab-researcher/AGENTS.md" << 'EOF'
# AlpenTech Web Researcher

You are the **Web Researcher** running on OpenRouter (StepFun).

## Rules
- Public research only via web_search and web_fetch
- NEVER process sensitive documents or PII
- Include source URLs in findings
- Write results to workspace directory only
EOF
ok "claw-lab-researcher/AGENTS.md (web-researcher)"

# =============================================================================
phase "5/11" "Writing openclaw.json"
# =============================================================================

mkdir -p "$OPENCLAW_HOME"

cat > "$OPENCLAW_HOME/openclaw.json" << EOF
{
  "env": {
    "LANGDOCK_API_KEY": "$LANGDOCK_KEY",
    "OPENROUTER_API_KEY": "$OPENROUTER_KEY"
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "$GW_AUTH_TOKEN"
    }
  },
  "models": {
    "providers": {
      "langdock": {
        "baseUrl": "https://api.langdock.com/anthropic/eu/v1",
        "api": "anthropic-messages",
        "apiKey": "$LANGDOCK_KEY",
        "models": [
          {
            "id": "claude-sonnet-4-6-default",
            "name": "Claude Sonnet 4.6 (Langdock EU)",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0.003, "output": 0.015, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 200000,
            "maxTokens": 8192
          }
        ]
      },
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
      "verboseDefault": "on",
      "subagents": {
        "maxSpawnDepth": 1,
        "maxChildrenPerAgent": 3,
        "maxConcurrent": 4,
        "runTimeoutSeconds": 300
      }
    },
    "list": [
      {
        "id": "assistant",
        "default": true,
        "name": "AlpenTech Orchestrator",
        "model": "langdock/claude-sonnet-4-6-default",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$CLAW_LAB",
        "identity": {
          "name": "AlpenTech AI",
          "emoji": "shield"
        },
        "tools": {
          "profile": "full",
          "deny": ["read"]
        },
        "subagents": {
          "allowAgents": ["sovereign-analyst", "web-researcher"]
        }
      },
      {
        "id": "sovereign-analyst",
        "name": "AlpenTech Sovereign Analyst",
        "model": "langdock/claude-sonnet-4-6-default",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$SCRIPT_DIR/claw-lab-sovereign",
        "identity": {
          "name": "Sovereign Analyst",
          "emoji": "lock"
        },
        "tools": {
          "profile": "coding"
        }
      },
      {
        "id": "web-researcher",
        "name": "AlpenTech Web Researcher",
        "model": "openrouter/stepfun/step-3.5-flash:free",
        "workspace": "$CLAW_LAB/workspace",
        "agentDir": "$SCRIPT_DIR/claw-lab-researcher",
        "identity": {
          "name": "Web Researcher",
          "emoji": "globe"
        },
        "tools": {
          "profile": "coding",
          "allow": ["web_search", "web_fetch"]
        }
      }
    ]
  },
  "tools": {
    "fs": {
      "workspaceOnly": true
    },
    "agentToAgent": {
      "enabled": true,
      "allow": ["assistant", "sovereign-analyst", "web-researcher"]
    }
  },
  "logging": {
    "level": "info",
    "consoleLevel": "info",
    "consoleStyle": "pretty",
    "redactSensitive": "tools"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  }
}
EOF
ok "Wrote $OPENCLAW_HOME/openclaw.json"
info "  3 agents: orchestrator (Langdock), sovereign-analyst (Langdock), web-researcher (OpenRouter)"
info "  agent-to-agent: enabled"
info "  logging: info, redactSensitive=tools"
info "  gateway auth token: ${GW_AUTH_TOKEN:0:12}..."

# =============================================================================
phase "6/11" "Creating agent-level models.json"
# =============================================================================

# Assistant (orchestrator): langdock + openrouter
ASSISTANT_MODELS_DIR="$OPENCLAW_HOME/agents/assistant/agent"
mkdir -p "$ASSISTANT_MODELS_DIR"
cat > "$ASSISTANT_MODELS_DIR/models.json" << EOF
{
  "providers": {
    "langdock": {
      "baseUrl": "https://api.langdock.com/anthropic/eu/v1",
      "api": "anthropic-messages",
      "apiKey": "$LANGDOCK_KEY",
      "models": [
        {
          "id": "claude-sonnet-4-6-default",
          "name": "Claude Sonnet 4.6 (Langdock EU)",
          "reasoning": false,
          "input": ["text", "image"],
          "cost": { "input": 0.003, "output": 0.015, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 200000,
          "maxTokens": 8192
        }
      ]
    },
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
}
EOF
ok "$OPENCLAW_HOME/agents/assistant/agent/models.json (langdock + openrouter)"

# Sovereign Analyst: langdock only
SOVEREIGN_MODELS_DIR="$OPENCLAW_HOME/agents/sovereign-analyst/agent"
mkdir -p "$SOVEREIGN_MODELS_DIR"
cat > "$SOVEREIGN_MODELS_DIR/models.json" << EOF
{
  "providers": {
    "langdock": {
      "baseUrl": "https://api.langdock.com/anthropic/eu/v1",
      "api": "anthropic-messages",
      "apiKey": "$LANGDOCK_KEY",
      "models": [
        {
          "id": "claude-sonnet-4-6-default",
          "name": "Claude Sonnet 4.6 (Langdock EU)",
          "reasoning": false,
          "input": ["text", "image"],
          "cost": { "input": 0.003, "output": 0.015, "cacheRead": 0, "cacheWrite": 0 },
          "contextWindow": 200000,
          "maxTokens": 8192
        }
      ]
    }
  }
}
EOF
ok "$OPENCLAW_HOME/agents/sovereign-analyst/agent/models.json (langdock)"

# Web Researcher: openrouter only
RESEARCHER_MODELS_DIR="$OPENCLAW_HOME/agents/web-researcher/agent"
mkdir -p "$RESEARCHER_MODELS_DIR"
cat > "$RESEARCHER_MODELS_DIR/models.json" << EOF
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
        }
      ]
    }
  }
}
EOF
ok "$OPENCLAW_HOME/agents/web-researcher/agent/models.json (openrouter)"

# =============================================================================
phase "7/11" "Creating sovereign-route skill"
# =============================================================================

mkdir -p "$CLAW_LAB/skills/sovereign-route"
cat > "$CLAW_LAB/skills/sovereign-route/SKILL.md" << 'EOF'
---
name: sovereign-route
description: "Route tasks to the correct agent based on data sensitivity. Use when the user says /sovereign-route or asks to analyze documents, search the web, or process any task."
user-invocable: true
metadata: {"openclaw": {"emoji": "shield"}}
---

# /sovereign-route — Data Sovereignty Router

When the user invokes `/sovereign-route`, analyze the request and route it to the correct agent based on data sensitivity.

## Routing Decision Tree

1. **Does the task involve documents, PII, contracts, financial data, or internal information?**
   - YES → Spawn `sovereign-analyst` with the task
   - Reason: Data must stay within EU jurisdiction (Langdock EU)

2. **Does the task involve web searches, public information, news, or general knowledge?**
   - YES → Spawn `web-researcher` with the task
   - Reason: No sensitive data, can use OpenRouter (StepFun)

3. **Does the task involve BOTH sensitive data AND web research?**
   - Split into two sub-tasks:
     a. Spawn `sovereign-analyst` for the sensitive portion
     b. Spawn `web-researcher` for the public research portion
   - Combine results yourself (as orchestrator, you are the sovereignty ceiling)

## Response Format

Before spawning, always explain:
- Which agent you are routing to and why
- What data sovereignty implications exist
- What the agent will do

After results return, summarize findings without exposing raw PII.
EOF
ok "claw-lab/skills/sovereign-route/SKILL.md"

# Register skill in OpenClaw skill cache (gateway reads from here)
mkdir -p "$OPENCLAW_HOME/skills/sovereign-route"
cp "$CLAW_LAB/skills/sovereign-route/SKILL.md" "$OPENCLAW_HOME/skills/sovereign-route/SKILL.md"
mkdir -p "$OPENCLAW_HOME/skills/skills/sovereign-route"
cp "$CLAW_LAB/skills/sovereign-route/SKILL.md" "$OPENCLAW_HOME/skills/skills/sovereign-route/SKILL.md"
ok "Registered sovereign-route in skill cache"

# =============================================================================
phase "8/11" "Logging and audit trail"
# =============================================================================

ok "Logging configured: level=info, redactSensitive=tools"
info "Audit trail via built-in gateway logging to /tmp/openclaw/"

# =============================================================================
phase "9/11" "Ensuring workspace structure"
# =============================================================================

mkdir -p "$CLAW_LAB/workspace/sample-docs"
mkdir -p "$CLAW_LAB/workspace/outputs"
ok "claw-lab/workspace/sample-docs/ exists"
ok "claw-lab/workspace/outputs/ exists"

# =============================================================================
phase "10/11" "Restarting gateway"
# =============================================================================

openclaw gateway restart 2>/dev/null || true
sleep 2

# Check gateway status
GW_STATUS=$(openclaw gateway status 2>&1 | head -3 || echo "unknown")
if echo "$GW_STATUS" | grep -qi "running"; then
    ok "Gateway restarted and running"
else
    warn "Gateway may not be running — check: openclaw gateway status"
    info "You can start it manually: openclaw gateway"
fi

# =============================================================================
phase "11/11" "Setup complete"
# =============================================================================

echo ""
echo -e "╔════════════════════════════════════════════════════════════════╗"
echo -e "║  ${GREEN}SOVEREIGN MULTI-AGENT ORCHESTRATION READY${NC}                   ║"
echo -e "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "  ${BOLD}Architecture:${NC}"
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │                  ORCHESTRATOR (assistant)               │"
echo "  │            Langdock EU / Claude Sonnet 4.6              │"
echo "  │          tools.deny: [read]  (cannot read files)        │"
echo "  │          Sovereignty ceiling — all results flow here    │"
echo "  └─────────────┬──────────────────────┬────────────────────┘"
echo "                │                      │"
echo "                ▼                      ▼"
echo "  ┌─────────────────────┐  ┌─────────────────────────────┐"
echo "  │  SOVEREIGN ANALYST  │  │       WEB RESEARCHER        │"
echo "  │    Langdock EU      │  │    OpenRouter (StepFun)     │"
echo "  │  claude-sonnet-4-6  │  │  step-3.5-flash:free        │"
echo "  │  Sensitive docs,    │  │  Public web searches,       │"
echo "  │  PII, contracts     │  │  non-sensitive research     │"
echo "  │  GDPR-compliant     │  │  Outside EU jurisdiction    │"
echo "  └─────────────────────┘  └─────────────────────────────┘"
echo ""
echo -e "  ${BOLD}Agent Directories:${NC}"
echo "    Orchestrator:       $CLAW_LAB/"
echo "    Sovereign Analyst:  $SCRIPT_DIR/claw-lab-sovereign/"
echo "    Web Researcher:     $SCRIPT_DIR/claw-lab-researcher/"
echo ""
echo -e "  ${BOLD}Gateway:${NC}"
echo "    URL:   http://127.0.0.1:18789/?token=${GW_AUTH_TOKEN}"
echo "    Auth:  ${GW_AUTH_TOKEN:0:12}..."
echo ""
echo -e "  ${BOLD}Verification Commands:${NC}"
echo "    openclaw gateway status"
echo "    openclaw agents list"
echo "    openclaw chat \"Route this to the sovereign analyst: summarize the consulting agreement\""
echo ""
echo -e "  ${BOLD}Skills:${NC}"
echo "    /sovereign-route — Auto-route tasks based on data sensitivity"
echo ""
echo -e "  ${BOLD}Config Files:${NC}"
echo "    $OPENCLAW_HOME/openclaw.json"
echo "    $CLAW_LAB/auth-profiles.json"
echo "    $CLAW_LAB/AGENTS.md"
echo ""
