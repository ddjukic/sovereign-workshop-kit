---
name: comparison-extractor
description: "Cross-reference two or more documents for consistency and conflicts. Use when the user says /comparison-extractor or asks to compare documents side by side."
user-invocable: true
metadata: {"openclaw": {"emoji": "balance_scale"}}
---

# Cross-Document Comparison Extractor

Compare the provided documents and identify:

## Analysis
1. **Overlapping entities** -- people, organizations, dates, amounts that appear in multiple documents
2. **Consistency check** -- do the documents agree on shared facts?
3. **Conflicts** -- any contradictions between documents
4. **Missing references** -- does one document reference something not found in others?

## Example Comparisons
- Invoice vs Contract: Do payment terms match? Is the invoiced amount within contract limits?
- HR Policy vs Financial Report: Does headcount in the policy match FTE in the report?
- Contract vs Research Paper: Are confidentiality obligations reflected in the paper's publication restrictions?

## Output Format
| Check | Doc A | Doc B | Status | Detail |
|-------|-------|-------|--------|--------|
| Payment terms | Net 30 (contract) | Net 45 (invoice) | CONFLICT | Invoice terms exceed contract |
