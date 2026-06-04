# Documentation Initialization Report

## Metadata

| Field              | Value                                  |
|--------------------|----------------------------------------|
| **Date**           | {{date}}                               |
| **Project**        | {{project_name}}                       |
| **Root Path**      | {{project_root}}                       |
| **Agent**          | Spec-Kit Extended Flow Documentation Init Agent |

---

## Initialization Summary

| Metric                          | Value |
|---------------------------------|-------|
| Source files analyzed            | {{source_files_count}} |
| Languages detected               | {{languages}} |
| Framework(s) identified          | {{frameworks}} |
| Module boundaries identified     | {{module_count}} |
| Documentation files created      | {{docs_created}} |
| Existing documentation preserved | {{docs_preserved}} |
| Items requiring human input      | {{human_input_count}} |

### Tech Stack

| Category | Technology | Evidence |
|----------|------------|----------|
| Language | {{language}} | {{evidence}} |
| Framework | {{framework}} | {{evidence}} |
| Database | {{database}} | {{evidence}} |
| Infrastructure | {{infra}} | {{evidence}} |

### Architecture Style

{{architecture_description}}

---

## Files Created

### Layer 1 — Global Constraints

| File | Status | Notes |
|------|--------|-------|
| `AGENTS.md` | {{created/augmented/skipped}} | {{notes}} |
| `docs/glossary.md` | {{created/skipped}} | {{notes}} |

### Layer 2 — Domain-Specific Context

| File | Status | Content Confidence | Notes |
|------|--------|-------------------|-------|
| `docs/architecture/overview.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |
| `docs/architecture/building-blocks.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |
| `docs/architecture/runtime.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |
| `docs/architecture/deployment.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |
| `docs/architecture/crosscutting.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |
| `docs/architecture/adr/001-initial-architecture.md` | {{created/skipped}} | {{high/medium/low}} | {{notes}} |

#### Module-Level Documentation

| File | Module Responsibility | Contracts Documented |
|------|----------------------|---------------------|
| `{{module_path}}/AGENTS.md` | {{responsibility}} | {{yes/partial/placeholder}} |

### Layer 3 — Reference

| File | Status | Notes |
|------|--------|-------|
| `docs/architecture/strategy.md` | {{created/skipped}} | {{notes}} |
| `docs/architecture/quality.md` | {{created/skipped}} | {{notes}} |
| `docs/architecture/risks.md` | {{created/skipped}} | {{notes}} |

---

## Content Inferred from Code

> Items below were populated based on code analysis. Confidence indicates how certain the inference is.

| # | Category | Inference | Evidence | Confidence | File Updated |
|---|----------|-----------|----------|------------|--------------|
| 1 | {{category}} | {{what_was_inferred}} | {{code_evidence}} | {{high/medium/low}} | {{file_path}} |

---

## Human Input Required

> These items cannot be inferred from code. They require human knowledge to complete.

| # | Priority | File | Section | Question |
|---|----------|------|---------|----------|
| 1 | {{P1/P2/P3}} | {{file_path}} | {{section}} | {{specific_question}} |

### Priority Key

- **P1** — Needed for the documentation layer to be functional (global constraints, top quality goals)
- **P2** — Important for agent effectiveness (interface contracts, key decisions rationale)
- **P3** — Valuable but not blocking (strategy details, comprehensive quality scenarios)

---

## Existing Documentation

> Pre-existing documentation that was found and preserved.

| File | Action Taken | Notes |
|------|--------------|-------|
| {{file_path}} | {{preserved/referenced/integrated}} | {{notes}} |

---

## Recommended Next Steps

> Prioritized actions for making the documentation layer effective.

1. **{{action}}** — {{rationale}}
2. **{{action}}** — {{rationale}}
3. **{{action}}** — {{rationale}}

---

## Verification

- [ ] Layer 1 (AGENTS.md) created with global constraints
- [ ] Layer 2 (architecture docs) created for all identified areas
- [ ] Layer 2 (module AGENTS.md) created for major modules
- [ ] Layer 3 (reference docs) created with appropriate placeholders
- [ ] No existing documentation was overwritten
- [ ] All inferred content includes evidence/rationale
- [ ] All unknowable items marked with `<!-- HUMAN INPUT REQUIRED -->`
- [ ] Mermaid used for all diagrams (no image embeds)
- [ ] Progressive disclosure maintained (summaries ≤ 200 tokens)
- [ ] ADR-001 created documenting current architecture baseline
