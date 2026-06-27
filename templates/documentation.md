# Documentation Reconciliation Report

## Metadata

| Field              | Value                          |
|--------------------|--------------------------------|
| **Date**           | {{date}}                       |
| **Spec Ref**       | {{spec_reference}}             |
| **Implementation** | {{implementation_ref}}         |
| **Agent**          | Spec-Kit Extended Flow Documentation Agent |

---

## Reconciliation Summary

| Metric                          | Count |
|---------------------------------|-------|
| Files changed in implementation | {{files_changed}} |
| Documentation layers affected   | {{layers_affected}} |
| Documentation files updated     | {{docs_updated}} |
| Conflicts identified            | {{conflict_count}} |
| Items requiring human review    | {{human_review_count}} |

---

## Conflicts (Human Resolution Required)

> These items represent contradictions between a **marked guideline** and current code behavior. The agent has NOT resolved them — a human must classify each conflict.

| # | Document | Guideline Stated | Code Behavior Observed | Layer | Category |
|---|---|----------|--------------------------|------------------------|-------|----------|
| 1 | {{document_path}} | {{what_docs_say}} | {{what_code_does}} | {{layer}} | {{category}} |

**Action required**: For each conflict, classify it: (a) **bug** — fix the code; (b) **stale guideline** — update the documentation; (c) **tech debt** — keep the guideline and add an entry to the AI Debt Register below referencing it. Then commit the resolution.

---

## Changes Made

### Layer 1 — Global Constraints (AGENTS.md)

| Change Type | Content | Rationale |
|-------------|---------|-----------|
| {{added/updated/removed}} | {{constraint_text}} | {{why}} |

### Layer 2 — Domain-Specific Context

#### Interface Contracts

| Module/Service | Change | File Updated |
|----------------|--------|--------------|
| {{module}} | {{change_description}} | {{file_path}} |

#### Architecture Decision Records

| ADR | Status | Summary |
|-----|--------|---------|
| {{adr_file}} | Created / Updated | {{decision_summary}} |

#### Building Blocks / Runtime / Deployment

| Section | File | Change Description |
|---------|------|--------------------|
| {{section}} | {{file_path}} | {{change_description}} |

### Layer 3 — Reference

#### AI Debt Register

| Pattern | Location | Guideline Ref | Why It Must Not Be Replicated |
|---------|----------|---------------|-------------------------------|
| {{pattern}} | {{file_path}} | {{guideline_reference}} | {{rationale}} |

---

## Layer Health

| Layer | Status | Notes |
|-------|--------|-------|
| Layer 1 — Global Constraints | {{healthy/stale/missing}} | {{notes}} |
| Layer 2 — Domain Context | {{healthy/stale/missing}} | {{notes}} |
| Layer 3 — Reference | {{healthy/stale/missing}} | {{notes}} |

---

## Verification

- [ ] Layer 1 (AGENTS.md / global constraints) checked
- [ ] Layer 2 (domain context, ADRs, contracts) checked
- [ ] Layer 3 (AI debt register, strategy, quality) checked
- [ ] Product context category verified
- [ ] Decisions and rationale category verified
- [ ] Interface contracts category verified
- [ ] Architecture boundaries category verified
- [ ] All documentation updates are in the same commit as the code
- [ ] No conflicts were auto-resolved (all flagged for human classification as bug / stale guideline / tech debt)
- [ ] Progressive disclosure maintained (summaries ≤ 200 tokens, pointers to depth)
