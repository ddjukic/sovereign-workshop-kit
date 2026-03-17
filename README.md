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

## Windows (WSL) -- Step-by-Step Instructions

If you are on Windows, you need to run this kit inside **Windows Subsystem for Linux (WSL)**. Follow every step below carefully.

### 1. Install WSL

Open **PowerShell as Administrator** (right-click the Start menu, select "Terminal (Admin)" or "PowerShell (Admin)") and run:

```powershell
wsl --install
```

This installs Ubuntu by default. **Restart your computer** when prompted.

### 2. First Launch -- Create Your Linux User

After restarting, open **Ubuntu** from the Start menu. It will finish installing and ask you to create a username and password. Pick something simple -- you will need the password occasionally.

### 3. Install Node.js 22+

Inside the Ubuntu terminal, run:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs git
node --version   # Should print v22.x.x or higher
```

### 4. Navigate to a Convenient Folder

To keep the kit on your Windows Desktop (so you can also see it in File Explorer):

```bash
cd /mnt/c/Users/YOUR_USERNAME/Desktop
```

Replace `YOUR_USERNAME` with your actual Windows username. You can also use `Downloads` instead of `Desktop`.

> **Tip:** To find your username, run `ls /mnt/c/Users/` and look for your name.

### 5. Clone and Run

```bash
git clone https://github.com/ddjukic/sovereign-workshop-kit.git
cd sovereign-workshop-kit
chmod +x setup.sh
./setup.sh --openrouter YOUR_OPENROUTER_KEY
```

### 6. Open the Dashboard

The script prints a URL at the end (e.g., `http://127.0.0.1:18789/?token=...`). Open that URL in your **Windows browser** (Chrome, Edge, etc.) -- WSL shares the network with Windows, so `127.0.0.1` works directly.

---

## macOS / Linux Instructions

### Prerequisites

- **Node.js 22+** -- install via [nvm](https://github.com/nvm-sh/nvm) or your package manager
- **git** -- pre-installed on macOS; `sudo apt install git` on Ubuntu/Debian

### Setup

```bash
git clone https://github.com/ddjukic/sovereign-workshop-kit.git
cd sovereign-workshop-kit
chmod +x setup.sh
./setup.sh --openrouter YOUR_OPENROUTER_KEY
```

Open the dashboard URL printed at the end of the script output.

---

## Other Commands

```bash
./setup.sh --status       # Check current state of your installation
./setup.sh --dry-run      # Preview what the script will do (no changes)
./setup.sh --restore      # Restore your personal OpenClaw config after the workshop
```

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

### Gateway won't start (WSL)

WSL without systemd cannot use `launchctl` or `systemd` daemons. The setup script handles this automatically by starting the gateway as a background process. If it still fails:

```bash
# Start the gateway manually in the foreground:
openclaw gateway --port 18789

# Or in the background:
nohup openclaw gateway --port 18789 > ~/.openclaw/logs/gateway.log 2>&1 &
```

### "model_not_found" or API errors

- Verify your OpenRouter key is valid: go to [openrouter.ai/keys](https://openrouter.ai/keys) and check the key is active.
- Re-run setup to update the key:
  ```bash
  ./setup.sh --openrouter YOUR_NEW_KEY
  ```
- The default model (`stepfun/step-3.5-flash:free`) is a free-tier model. If it becomes unavailable, check the [OpenRouter models page](https://openrouter.ai/models) for alternatives.

### Node.js version too old

The kit requires Node.js 22 or later. Check your version:

```bash
node --version
```

If it's below v22, upgrade:

```bash
# Using nvm (recommended):
nvm install 22
nvm use 22

# Or on Ubuntu/Debian:
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### Port 18789 already in use

Another process is using the gateway port. Find and stop it:

```bash
lsof -i :18789          # macOS/Linux
kill <PID>               # Replace <PID> with the process ID shown
openclaw gateway start   # Restart the gateway
```

### Dashboard opens but agent doesn't respond

1. Check the gateway is running: `openclaw gateway status`
2. Check auth is configured: `cat claw-lab/auth-profiles.json`
3. Check logs: `cat ~/.openclaw/logs/gateway.log`

### WSL: "Permission denied" when running setup.sh

```bash
chmod +x setup.sh
./setup.sh --openrouter YOUR_KEY
```

If you cloned onto a Windows filesystem path (e.g., `/mnt/c/...`), file permissions can be tricky. Try cloning into your WSL home directory instead:

```bash
cd ~
git clone https://github.com/ddjukic/sovereign-workshop-kit.git
cd sovereign-workshop-kit
chmod +x setup.sh
./setup.sh --openrouter YOUR_KEY
```

---

## Companion App

The workshop companion app is available at:

**[https://agentic-workshop-aiat.vercel.app](https://agentic-workshop-aiat.vercel.app)**

Use it for guided exercises, real-time progress tracking, and mission briefings during the workshop.

---

## What's in the Kit

```
sovereign-workshop-kit/
  setup.sh                        # Automated setup script (idempotent, safe to re-run)
  README.txt                      # Quick-start text reference
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
