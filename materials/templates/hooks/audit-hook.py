#!/usr/bin/env python3
"""PostToolUse audit hook for OpenClaw -- logs every tool call to JSONL.

Install: Copy to ~/.openclaw/hooks/audit-hook.py
Configure in openclaw.json:
  hooks: {
    PostToolUse: [{ type: "command", command: "python3 ~/.openclaw/hooks/audit-hook.py", async: true }]
  }
"""
import json
import sys
import os
from datetime import datetime, timezone

LOG_DIR = os.path.expanduser("~/.openclaw/audit-logs")
os.makedirs(LOG_DIR, exist_ok=True)

TOOL_EMOJI = {
    "read": "book", "write": "pencil", "edit": "memo",
    "exec": "computer", "grep": "mag", "browser": "globe_with_meridians",
    "sessions_spawn": "busts_in_silhouette", "sessions_send": "speech_balloon",
}

def main():
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        return

    tool = event.get("tool_name", "unknown")
    agent_id = event.get("agent_id", "unknown")
    session_id = event.get("session_id", "unknown")[:12]
    tool_input = event.get("tool_input", {})

    # Extract key detail based on tool type
    if tool == "read":
        detail = tool_input.get("file_path", "")
    elif tool == "exec":
        detail = tool_input.get("command", "")[:200]
    elif tool in ("write", "edit"):
        detail = tool_input.get("file_path", "")
    elif tool == "grep":
        detail = tool_input.get("pattern", "")
    elif tool == "sessions_spawn":
        detail = f"target={tool_input.get('agentId', '?')}"
    else:
        detail = str(tool_input)[:200]

    log_entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "agent": agent_id,
        "session": session_id,
        "tool": tool,
        "detail": detail,
    }

    log_file = os.path.join(LOG_DIR, f"{datetime.now().strftime('%Y-%m-%d')}.jsonl")
    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry) + "\n")

if __name__ == "__main__":
    main()
