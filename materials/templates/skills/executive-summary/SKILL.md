---
name: executive-summary
description: "Generate a concise executive summary of any document. Use when the user says /executive-summary or asks for a C-level summary of a document."
user-invocable: true
metadata: {"openclaw": {"emoji": "memo"}}
---

# Executive Summary Generator

Create a structured executive summary suitable for C-level review.

## Format
1. **One-line synopsis** (max 20 words)
2. **Key facts** (5-7 bullet points, quantified where possible)
3. **Action items** (what decisions or actions does this document require?)
4. **Risk factors** (any concerns, deadlines, or dependencies)
5. **Recommendation** (your assessment in 1-2 sentences)

## Rules
- Write for a busy CEO who has 60 seconds to read this
- Quantify everything possible (dates, amounts, percentages)
- Flag any PII -- do NOT include it in the summary
- Use German business terminology where appropriate (Geschaeftsfuehrer, Betriebsrat, etc.)
