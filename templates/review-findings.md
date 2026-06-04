# Review Findings

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

## Recommendations for Re-Implementation

<!-- Only populated when verdict is FAIL. Provides actionable guidance for the next implementation iteration. -->

{{recommendations}}

---

## Iteration History

| Iteration | Verdict | Critical Issues | Date       |
|-----------|---------|-----------------|------------|
| 1         | {{verdict}} | {{count}}   | {{date}}   |
