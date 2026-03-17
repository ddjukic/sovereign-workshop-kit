---
name: compliance-checker
description: "Check documents for regulatory compliance issues. Use when the user says /compliance-checker or asks to check a document for GDPR, EU AI Act, or Austrian labor law compliance."
user-invocable: true
metadata: {"openclaw": {"emoji": "clipboard"}}
---

# Compliance Checker

Analyze the provided document for compliance with the following regulations:

## Checklist
1. **GDPR (General Data Protection Regulation)**
   - Does the document contain personal data? If so, is there a legal basis for processing?
   - Are data retention periods specified?
   - Are data subject rights addressed?

2. **EU AI Act (effective August 2026)**
   - Does the document reference AI systems? If so, what risk category?
   - Are transparency requirements met?
   - Is human oversight documented?

3. **Austrian Labor Law (ArbVG, AZG)**
   - For HR documents: Are works council (Betriebsrat) requirements addressed?
   - Are working time limits compliant with AZG?

4. **Contractual Obligations**
   - Are confidentiality clauses present and adequate?
   - Are liability limitations reasonable?
   - Are termination provisions clear?

## Output Format
For each regulation, report:
- Status: COMPLIANT / NON-COMPLIANT / NEEDS REVIEW / NOT APPLICABLE
- Finding: specific clause or absence noted
- Recommendation: suggested action if non-compliant
