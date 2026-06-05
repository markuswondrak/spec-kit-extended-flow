# Review Findings

<!--
Filename pattern: review-findings-{iteration}-{VERDICT}.md
Example: review-findings-1-FAIL.md, review-findings-2-PASS.md
The verdict is encoded in the filename for machine consumption.
-->

## Metadata

| Field            | Value                |
|------------------|----------------------|
| **Date**         | {{date}}             |
| **Iteration**    | {{iteration}}        |
| **Spec Ref**     | {{spec_reference}}   |
| **Reviewer**     | Spec-Kit Extended Flow Reviewer |

---

## Verdict

> **{{VERDICT}}**

<!-- The verdict MUST be exactly "PASS" or "FAIL". No other value is accepted. -->

---

## Summary

{{summary}}

---

## Findings

| # | Severity | Category         | Description                          | Location         |
|---|----------|------------------|--------------------------------------|------------------|
| 1 | CRITICAL / HIGH / MEDIUM / LOW | Bug / Spec Deviation / Edge Case / Missing Feature | {{description}} | {{file:line}} |

---

## Details

### Finding 1: {{title}}

**Severity**: {{severity}}
**Category**: {{category}}
**Location**: `{{file}}:{{line}}`

**Description**:
{{detailed_description}}

**Expected Behavior** (per spec):
{{expected}}

**Actual Behavior**:
{{actual}}

**Suggested Fix**:
{{suggestion}}

---

## Recommendations for Fix

<!-- Only populated when verdict is FAIL. Provides actionable guidance for the next fix iteration. -->

{{recommendations}}

---

## Iteration History

| Iteration | Verdict | Critical Issues | Date       |
|-----------|---------|-----------------|------------|
| 1         | {{verdict}} | {{count}}   | {{date}}   |
