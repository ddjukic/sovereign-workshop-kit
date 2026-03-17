Sovereign Agentic Systems Workshop — Setup Kit
AI Factory Austria, March 17-18, 2026
================================================

QUICK START (3 steps):

  1. Open a terminal in this folder

  2. Run the setup script with your OpenRouter API key:

     chmod +x setup.sh
     ./setup.sh --openrouter YOUR_OPENROUTER_KEY

     Get a free key at: https://openrouter.ai/keys

  3. Open the dashboard URL printed at the end

OPTIONAL — EU Sovereign Agent (requires Langdock account):

     ./setup.sh --openrouter YOUR_KEY --langdock YOUR_LANGDOCK_KEY

OTHER COMMANDS:

     ./setup.sh --status       # Check current state
     ./setup.sh --dry-run      # Preview without changes
     ./setup.sh --restore      # Restore your personal config

REQUIREMENTS:
  - macOS or Linux (WSL on Windows)
  - Node.js 22+ (the script will check)
  - Internet access (for npm install + OpenRouter API)

HELP:
  Workshop companion app: https://agentic-workshop-aiat.vercel.app
  OpenClaw documentation: https://docs.openclaw.ai
