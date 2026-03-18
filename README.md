# Sovereign Agentic Systems Workshop

**AI Factory Austria -- March 17-18, 2026**

Build, configure, and secure autonomous AI agents using [OpenClaw](https://docs.openclaw.ai) with enterprise-grade defense-in-depth patterns. This kit contains everything you need to follow along during the workshop.

---

## Quick Start (3 Steps)

1. **Clone this repository**
   ```bash
   git clone https://github.com/ddjukic/sovereign-workshop-kit.git
   cd sovereign-workshop-kit
   ```

2. **Get a free OpenRouter API key** at [openrouter.ai/keys](https://openrouter.ai/keys)

3. **Run the setup script**
   ```bash
   chmod +x setup.sh
   ./setup.sh --openrouter YOUR_OPENROUTER_KEY
   ```

That's it. The script installs OpenClaw, creates a sandboxed `claw-lab/` workspace, configures your agent, starts the gateway, and prints a dashboard URL.

> **Optional -- EU Sovereign Agent** (requires a [Langdock](https://langdock.com) account):
> ```bash
> ./setup.sh --openrouter YOUR_KEY --langdock YOUR_LANGDOCK_KEY
> ```

---

## Lightning.ai Cloud Setup (Recommended)

**No local installation required.** Lightning.ai provides a free browser-based IDE with terminal access -- ideal for workshop participants who want to skip local setup entirely.

### 1. Create a Lightning.ai account

Sign up at [lightning.ai/sign-up](https://lightning.ai/sign-up) (free, no credit card required). Do this **at least 3 days before the workshop** -- account verification can take time.

### 2. Create a new Studio

Go to [lightning.ai](https://lightning.ai), click **New Studio**, and select a free CPU instance.

### 3. Install Node.js and clone the kit

In the Studio terminal:

```bash
nvm install --lts
git clone https://github.com/ddjukic/agentic-workshop-kit-aiat.git
cd agentic-workshop-kit-aiat
```

### 4. Run setup with `--lightning`

```bash
./setup.sh --openrouter YOUR_OPENROUTER_KEY --lightning
```

The `--lightning` flag automatically:
- Reads your `$LIGHTNING_API_KEY` from the Studio environment
- Binds the gateway to LAN so Lightning's proxy can reach it
- Registers port 18789 with Lightning for external access

### 5. Open the dashboard

The script prints a URL like:
```
https://18789-XXXX.cloudspaces.litng.ai/?token=...
```

Open it in your browser. If the dashboard shows **"pairing required"**, run in your Studio terminal:

```bash
openclaw devices list
openclaw devices approve <request-id>
```

Then refresh the dashboard.

---

## macOS / Linux Instructions

### Prerequisites

- **Node.js 22+** -- install via [nvm](https://github.com/nvm-sh/nvm) or your package manager
- **git** -- pre-installed on macOS; `sudo apt install git` on Ubuntu/Debian

### Setup

```bash
git clone https://github.com/ddjukic/agentic-workshop-kit-aiat.git
cd agentic-workshop-kit-aiat
chmod +x setup.sh
./setup.sh --openrouter YOUR_OPENROUTER_KEY
```

Open the dashboard URL printed at the end of the script output.

---

## Windows (WSL)

If you are on Windows, you need to run this kit inside **Windows Subsystem for Linux (WSL)**. If WSL setup feels cumbersome, use the [Lightning.ai cloud setup](#lightningai-cloud-setup-recommended) instead.

### 1. Install WSL

Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

**Restart your computer** when prompted.

### 2. First Launch

Open **Ubuntu** from the Start menu. Create a username and password when prompted.

### 3. Install Node.js 22+

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs git
node --version   # Should print v22.x.x or higher
```

### 4. Clone and Run

```bash
cd /mnt/c/Users/YOUR_USERNAME/Desktop
git clone https://github.com/ddjukic/agentic-workshop-kit-aiat.git
cd agentic-workshop-kit-aiat
chmod +x setup.sh
./setup.sh --openrouter YOUR_OPENROUTER_KEY
```

### 5. Open the Dashboard

The script prints a URL (e.g., `http://127.0.0.1:18789/?token=...`). Open it in your **Windows browser** -- WSL shares the network with Windows.

---

## Other Commands

```bash
./setup.sh --status       # Check current state of your installation
./setup.sh --dry-run      # Preview what the script will do (no changes)
./setup.sh --restore      # Restore your personal OpenClaw config after the workshop
```

---

## Day 2: Sovereign Multi-Agent Setup

After completing the Day 1 single-agent missions, upgrade to a 3-agent sovereign architecture:

```bash
chmod +x sovereign_multi_agents.sh
./sovereign_multi_agents.sh --openrouter YOUR_OPENROUTER_KEY --langdock YOUR_LANGDOCK_KEY
```

This creates three agents with **data sovereignty by design**:

| Agent | Provider | Role |
|-------|----------|------|
| **Orchestrator** | Langdock EU (Claude Sonnet 4.6) | Routes tasks to sub-agents, never reads files directly |
| **Sovereign Analyst** | Langdock EU (Claude Sonnet 4.6) | Processes sensitive documents, PII extraction, contracts |
| **Web Researcher** | OpenRouter (StepFun 3.5 Flash) | Public web searches, non-sensitive research only |

**Why this architecture?** The orchestrator sees all sub-agent results via `sessions_spawn`, making it the *sovereignty ceiling*. It must run on Langdock EU so sensitive data returned by the analyst never leaves EU jurisdiction. The web researcher runs on OpenRouter (free tier) but only handles public, non-sensitive tasks.

### Usage

```bash
# Preview what will be configured (no changes)
./sovereign_multi_agents.sh --dry-run --openrouter sk-or-... --langdock sk-...

# Full setup
./sovereign_multi_agents.sh --openrouter sk-or-... --langdock sk-...

# Help
./sovereign_multi_agents.sh --help
```

### Verification

After setup, open the dashboard and try:

| Test | What to Type |
|------|-------------|
| **Delegation to analyst** | *"Analyze the consulting agreement in sample-docs/"* |
| **Delegation to researcher** | *"Search for the latest NVIDIA GTC announcements"* |
| **Sovereignty routing** | Use `/sovereign-route` to auto-classify and route any task |

Check agent status: `openclaw agents list`

---

## Workshop Missions

Once setup completes, try these in the OpenClaw dashboard:

| Mission | What to Do |
|---------|------------|
| **0 -- Smoke Test** | Type: *"Hello, what model are you running on?"* |
| **1 -- First Extraction** | *"Read 01-consulting-agreement.txt and extract all parties, dates, and key obligations. Write result to outputs/."* |
| **2 -- Auditor Config** | Swap AGENTS.md: `cp claw-lab/configs/AGENTS-mission2.md claw-lab/AGENTS.md` then `openclaw gateway restart` |

---

## Troubleshooting

### Gateway won't start (WSL / Lightning)

WSL and Lightning Studios lack systemd. The setup script handles this automatically by starting the gateway as a background process. If it still fails:

```bash
openclaw gateway --port 18789
```

### Lightning: "Nothing running here yet"

The port may not be registered with Lightning. Run:

```bash
python3 -c "from lightning_sdk import Studio; Studio().add_ports(18789)"
```

### Lightning: "pairing required"

After opening the dashboard, approve the device from your Studio terminal:

```bash
openclaw devices list
openclaw devices approve <request-id>
```

### "model_not_found" or API errors

- Verify your OpenRouter key at [openrouter.ai/keys](https://openrouter.ai/keys)
- Re-run setup: `./setup.sh --openrouter YOUR_NEW_KEY`

### Node.js version too old

```bash
# Using nvm (recommended):
nvm install 22 && nvm use 22

# Or on Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Port 18789 already in use

```bash
lsof -i :18789
kill <PID>
openclaw gateway start
```

### Dashboard opens but agent doesn't respond

1. Check the gateway: `openclaw gateway status`
2. Check auth: `cat claw-lab/auth-profiles.json`
3. Check logs: `cat ~/.openclaw/logs/gateway.log`

---

## Companion App

**[https://agentic-workshop-aiat.vercel.app](https://agentic-workshop-aiat.vercel.app)**

Guided exercises, real-time progress tracking, and mission briefings during the workshop.

---

## What's in the Kit

```
sovereign-workshop-kit/
  setup.sh                        # Day 1: single-agent setup (idempotent, safe to re-run)
  sovereign_multi_agents.sh       # Day 2: 3-agent sovereign orchestration setup
  materials/
    sample-docs/                  # 5 business documents for extraction exercises
      gold-standard/              # Reference extraction outputs for comparison
      extraction-schema.json      # Schema defining expected extraction fields
    templates/                    # Agent configs, workspace templates, skills, hooks
    workshop-kit/                 # Mission-specific AGENTS.md and openclaw configs
```

---

## License

Workshop materials provided for educational use during AI Factory Austria events.
