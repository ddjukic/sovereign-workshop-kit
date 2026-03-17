---
name: doc-intel
description: "Set up a document intelligence pipeline with PII detection. Use when the user says /doc-intel or asks to configure document extraction and analysis."
user-invocable: true
metadata: {"openclaw": {"emoji": "page_facing_up"}}
---

# Document Intelligence Pipeline

Configure a single-agent document intelligence setup with PII detection and structured extraction.

## Step 1: Configure Agent

Set the current agent's AGENTS.md to include:
- Document extraction against the AlpenTech extraction schema
- PII detection checklist (SV-Nr, passport numbers, IBANs, addresses, phone, email, health data)
- Sensitivity flagging (CONFIDENTIAL, ATTORNEY-CLIENT PRIVILEGE, DO NOT DISTRIBUTE)
- Structured JSON output format

## Step 2: Load Extraction Schema

Write the extraction schema to the workspace:
- Document types: legal_contract, commercial_invoice, financial_report, hr_policy, research_paper
- Entity extraction: organizations, people, dates, monetary values
- Key facts array
- Summary field

## Step 3: Test

Ask the user to send a document for processing. Process it against the schema and report:
1. Structured extraction (JSON)
2. PII report with counts
3. Sensitivity flags
