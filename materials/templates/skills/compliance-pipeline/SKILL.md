---
name: compliance-pipeline
description: "Deploy a compliance checking pipeline with analyst + compliance checker agents. Use when the user says /compliance-pipeline or asks to set up regulatory compliance checking."
user-invocable: true
metadata: {"openclaw": {"emoji": "balance_scale"}}
---

# Compliance Pipeline Deployment

Deploy a two-agent compliance pipeline: an analyst extracts data, then a compliance checker evaluates it against regulations.

## Step 1: Create Agent Workspaces

```bash
mkdir -p ~/.openclaw/workspace-compliance-analyst
mkdir -p ~/.openclaw/workspace-compliance-checker
```

## Step 2: Configure Agents

### Compliance Analyst
- Model: langdock/claude-sonnet-4-5 (EU-hosted)
- Role: Extract document content, flag PII, identify regulatory touchpoints
- Sandbox: network:none
- Forwards extraction to compliance checker

### Compliance Checker
- Model: langdock/claude-sonnet-4-5 (EU-hosted)
- Role: Evaluate extraction against GDPR, EU AI Act, Austrian labor law
- Output: compliance status per regulation with findings and recommendations

## Step 3: Patch Gateway Config

Add both agents with Langdock provider, configure subagent delegation from analyst to checker.

## Step 4: Test

Suggest: "Check our consulting agreement for GDPR compliance"
