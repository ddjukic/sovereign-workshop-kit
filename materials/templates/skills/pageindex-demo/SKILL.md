---
name: pageindex-demo
description: "Deploy a 2-agent comparison demo: one with PageIndex MCP for document intelligence, one baseline. Use when the user says /pageindex-demo or asks to compare tool-augmented vs baseline extraction."
user-invocable: true
disable-model-invocation: true
metadata: {"openclaw": {"emoji": "microscope"}}
---

# PageIndex vs Baseline: 2-Agent Comparison Demo

Deploy two Haiku agents side by side to demonstrate how MCP tooling changes extraction quality on the same document.

## Prerequisites

1. PageIndex API key from [dash.pageindex.ai/api-keys](https://dash.pageindex.ai/api-keys)
2. Free tier: 200 pages, sufficient for this demo
3. Sample document converted to PDF (PageIndex MCP requires PDF format)

## Step 1: Convert Sample Document to PDF

```bash
# Using pandoc (install: brew install pandoc)
pandoc materials/sample-docs/01-consulting-agreement.txt \
  -o ~/.openclaw/workspace-pageindex/consulting-agreement.pdf \
  --pdf-engine=wkhtmltopdf

# Or using wkhtmltopdf directly
wkhtmltopdf materials/sample-docs/01-consulting-agreement.txt \
  ~/.openclaw/workspace-pageindex/consulting-agreement.pdf
```

## Step 2: Create Workspaces

```bash
mkdir -p ~/.openclaw/workspace-pageindex
mkdir -p ~/.openclaw/workspace-baseline
```

## Step 3: Write AGENTS.md for Each Agent

### Agent A: Extractor with PageIndex (`~/.openclaw/workspace-pageindex/AGENTS.md`)

You are a document intelligence agent with access to PageIndex MCP for advanced document analysis.

**Workflow:**
1. Use `process_document` to index the PDF into PageIndex's tree structure
2. Wait for processing to complete (check status)
3. Query the indexed document for entities, PII, and key facts
4. Produce structured JSON extraction

**Output format:** JSON matching the AlpenTech extraction schema.
**Narrate every step** for workshop observability.

### Agent B: Baseline Extractor (`~/.openclaw/workspace-baseline/AGENTS.md`)

You are a document extraction agent. You work directly from document text without external tools.

**Workflow:**
1. Read the document text from the provided file
2. Extract all entities, PII, and key facts in a single pass
3. Produce structured JSON extraction

**Output format:** JSON matching the AlpenTech extraction schema.
**Narrate every step** for workshop observability.

## Step 4: Patch Gateway Config

Add the following agents to `agents.list`:

### Agent A: extractor-with-pageindex
- Model: `langdock/claude-haiku-4-5`
- Workspace: `~/.openclaw/workspace-pageindex`
- Tools: profile "full"
- MCP: PageIndex server (HTTP, API key auth)

### Agent B: extractor-baseline
- Model: `langdock/claude-haiku-4-5`
- Workspace: `~/.openclaw/workspace-baseline`
- Tools: profile "minimal", allow ["read"]

## Step 5: Run the Demo

Send the same prompt to both agents:

> Extract all entities, PII, and key facts from consulting-agreement.pdf.
> Output structured JSON matching the AlpenTech extraction schema.

## Step 6: Compare Results

Show side-by-side in the OpenClaw UI:
1. **Token usage** — visible in OpenClaw session view
2. **Extraction quality** — compare against gold standard
3. **PII detection completeness** — count PII items found by each
4. **Processing time** — wall clock from prompt to response

## Teaching Point

Same model (Haiku), same document, same prompt. The difference is the tool.
But the PageIndex tool sends the document to a US cloud — that is the sovereignty trade-off.
