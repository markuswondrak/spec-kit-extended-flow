# Extended Flow — Template Bloat Fix Proposal

> **Target:** `extended-flow` extension source (the upstream project that ships `.specify/extensions/extendedflow/`).
> **Goal:** Eliminate redundant content in `project-init`-generated template overrides so every subsequent SDD cycle stops paying double for rules already in `AGENTS.md`.
> **Status:** Proposal — apply to upstream `extended-flow` repo.

---

## TL;DR

`speckit.extendedflow.project-init` generates template overrides that:
1. List `AGENTS.md` in a "Pre-Reading (Mandatory)" table — even though `AGENTS.md` is **always loaded** (per `documentation-init.md` line 30).
2. Re-state the AGENTS.md §2 rules verbatim *after* an HTML comment saying "DO NOT re-state rules".
3. Waste ~30–40% of override tokens on duplicated Layer-1 content.

**Fix:** Add a "Template Generation Contract" to `project-init.md` that forbids re-stating Layer-1 rules and forbids mandatory-reading tables for always-loaded files. Rewrite Phase 2 instructions to "reference, don't re-state".

---

## Evidence (from doc-simplifier-app generated overrides)

### Defect 1 — Redundant Pre-Reading tables

Every override opens with a 5–7 row "Pre-Reading (Mandatory)" table listing `AGENTS.md`, `constitution.md`, `patterns.md`, `glossary.md`, `DESIGN.md`.

`AGENTS.md` is **always in context** (`documentation-init.md` line 30: *"This file is loaded in EVERY agent session"*). Listing it as "MUST read" is noise.

### Defect 2 — Rules re-stated after "don't re-state" comment

`plan-template.md` contains:
```html
<!-- DO NOT re-state rules from these documents. Reference them instead. -->
…then immediately a "Convention Gates" table re-listing all 6 AGENTS.md §2 rules verbatim:
- BANNED Text(), BANNED AlertDialog, BANNED isPremiumProvider, MANDATORY AppLogger, MANDATORY Feature-oriented, MANDATORY Minimum standards.
checklist-template.md has two full sections ("Accessibility Verification", "Banned Pattern Verification") re-enumerating every banned/mandatory rule with its rationale.
spec-template.md "Accessibility Requirements" re-states "Text() → ScaledText, AlertDialog → BaseAlertDialog".
tasks-template.md repeats "Convention Check: AGENTS.md §2 compliance" per phase.
Defect 3 — Token cost
File	Words	Redundant share
AGENTS.md (always loaded)	857	—
plan-template.md override	1,166	~35%
spec-template.md override	1,137	~30%
tasks-template.md override	1,850	~30%
checklist-template.md override	1,081	~45%
constitution-template.md override	460	~20%
Overrides total	6,551	~32% redundant
Every speckit.specify/plan/tasks/checklist run loads the template + AGENTS.md → pays twice for the same rules.
Root Cause
project-init.md Phase 2 (lines 129–165) instructs the agent to:
- "Embed conventions" (§2.4)
- "Add convention checks" (§2.2)
- "Add architecture compliance checks" (§2.5)
…with no guardrail distinguishing:
- Layer-1 content (rules in AGENTS.md, always loaded → must NOT be re-stated, only pointed to)
- Project-specific structure (file paths, domain entities, tech stack → must be embedded, since NOT in AGENTS.md)
The agent cannot tell these apart, so it embeds everything, including the rules. The layered documentation model that documentation-init builds is flattened back into monolithic templates by project-init.
Proposed Changes
Change A — Add "Template Generation Contract" to project-init.md
Insert a new section after "Core Principle" (after line 16) and before "When You Run" (line 20):
## Template Generation Contract

Generated overrides MUST respect the layered documentation model (see `speckit.extendedflow.documentation-init.md`). The layering collapses if templates re-state Layer-1 content.

### Layer awareness

| Layer | File | Loading | Template rule |
|-------|------|---------|---------------|
| Layer 1 | Root `AGENTS.md` | **Always loaded** | NEVER re-state. Point by anchor only (e.g., `AGENTS.md §2`). NEVER list in a "Pre-Reading" table. |
| Layer 2 | `docs/architecture/*`, nested `AGENTS.md`, `patterns.md`, `glossary.md` | Task-scoped | Link by anchor when relevant. Do NOT pre-declare as mandatory reading. |
| Layer 3 | `strategy.md`, `quality.md`, `risks.md` | Rarely | Link only when the template section is strategic. |

### What to EMBED (project-specific, NOT in AGENTS.md)

- Actual file paths from the code graph (e.g., `lib/features/<feature>/domain/entities/`)
- Domain entities and ubiquitous language (e.g., `AnalysisResult`, `QuotaStatus`)
- Tech stack versions (e.g., `Dart ^3.10.4`, `Flutter 3.10.4+`)
- Naming conventions derived from the codebase
- Test directory structure mirroring `lib/`

### What to REFERENCE (already in AGENTS.md / constitution.md)

- BANNED patterns (`Text()`, `AlertDialog`, `isPremiumProvider`)
- MANDATORY patterns (`AppLogger`, feature-oriented architecture, accessibility standards)
- Quality goals, core principles
- Test runner rules

Reference pattern: `See AGENTS.md §2` — one line, no re-statement.

### Pre-Reading Section Rule

Generated templates MUST NOT contain a "Pre-Reading (Mandatory)" table that lists `AGENTS.md` or `constitution.md`. These are always-loaded or command-loaded by the SDD workflow itself.

If on-demand Layer-2 docs are relevant to a template section, link them inline at that section — not in a top-of-file mandatory-reading block.

### Checklist Exception

Checklists MAY contain `[ ]` items that *name* a rule-family as a single consolidated line, e.g.:
- `[ ] AGENTS.md §2 BANNED patterns verified (no Text(), no AlertDialog, no isPremiumProvider in UI)`

But checklists MUST NOT re-enumerate each rule with its full rationale in separate items.
Change B — Rewrite Phase 2 sub-sections 2.1–2.5 in project-init.md
Replace lines 129–165 with the following (removes "Embed conventions" language; enforces reference-vs-embed):
### 2.1 `spec-template.md` (Focus: The "What" and Domain)

Rewrite the template to:
- **Force ubiquitous language**: Replace generic placeholders with the actual domain entities identified in Phase 1 (e.g., `AnalysisResult`, not "[Entity 1]")
- **Add domain impact sections**: Require specification of how new features impact core domain entities
- **Reference business invariants**: Point to AGENTS.md/constitution.md for invariants — do NOT re-state them
- **Add acceptance criteria patterns**: Use the project's actual testing conventions (e.g., BDD scenarios if the project uses BDD)
- **Reference Layer-1 rules**: Accessibility/quota rules are referenced as `See AGENTS.md §2`, never re-enumerated

### 2.2 `plan-template.md` (Focus: The "How" and Architecture)

Rewrite the template to:
- **Embed actual file placement**: Replace generic directory trees with the real project structure from the code graph
- **Embed tech stack table**: Concrete versions and primary dependencies (NOT in AGENTS.md)
- **Reference conventions**: Naming, file placement, and architectural boundaries are pointed to (`See AGENTS.md §2`, `See docs/architecture/building-blocks.md`) — NOT re-stated
- **Add dependency justification gate**: Require explicit justification for new dependencies (project-specific decision, not a Layer-1 rule)

### 2.3 `tasks-template.md` (Focus: Execution and Conventions)

Rewrite the template to:
- **Use actual file paths**: Replace generic `src/models/` with the project's real directory structure
- **Embed testing conventions**: Actual test paths and runner command (project-specific)
- **Add parallel execution rules**: Based on the project's module boundaries
- **Reference code style**: Linting/formatting rules are pointed to (`See AGENTS.md §2`, `See constitution.md`) — NOT re-enumerated per phase
- **Single convention checkpoint**: One consolidated `[ ] AGENTS.md §2 compliance verified` item per phase, not a re-listing of every rule

### 2.4 `constitution-template.md` (Focus: Project Principles)

Rewrite the template to:
- **Infer principles from code**: Identify existing quality goals from code patterns (e.g., extensive error handling → reliability)
- **Add tech-specific constraints**: Tech stack, testing standards, architectural invariants NOT already in AGENTS.md
- **Reference existing conventions**: Naming, file placement, code style already in AGENTS.md are pointed to, not duplicated
- **Amendment-only**: If a constitution exists, the template is for amendments only — reference the base, do not re-state it

### 2.5 `checklist-template.md` (Focus: Quality Gates)

Rewrite the template to:
- **Add architecture compliance checks**: Verify implementations follow the identified architectural patterns
- **Add domain language checks**: Verify new features use the correct ubiquitous language
- **Add file placement checks**: Verify files are placed per project conventions
- **Consolidated rule-family items**: Each AGENTS.md §2 rule-family is ONE checkbox naming the family (e.g., `[ ] AGENTS.md §2 BANNED patterns verified`), NOT a separate item per rule with rationale
- **No Pre-Reading table**: The checklist assumes AGENTS.md is already loaded; reference it by anchor in items
Change C — Add guardrail to File Quality Rules + clarify documentation-init.md
C.1 In project-init.md, append to the "File Quality Rules" section (after line 225) two new bullets:
- **No Layer-1 re-statement**: Templates MUST NOT re-state rules from AGENTS.md or constitution.md. Reference by anchor only (`AGENTS.md §2`). See Template Generation Contract.
- **No mandatory-reading tables for always-loaded files**: Templates MUST NOT include a "Pre-Reading (Mandatory)" table listing AGENTS.md or constitution.md. Link Layer-2 docs inline at the relevant section instead.
C.2 In documentation-init.md, append to the Layer 1 section (after line 37, inside "What to include") a clarifying bullet:
- **Downstream contract**: Because AGENTS.md is always loaded, `project-init`-generated templates MUST NOT re-list it in "Pre-Reading" tables or re-state its rules. Templates reference AGENTS.md by anchor only.
Verification
After applying Changes A–C to the upstream extended-flow source, re-run speckit.extendedflow.project-init on a test project and verify:
- No generated override contains a "Pre-Reading (Mandatory)" table listing AGENTS.md or constitution.md.
- No generated override re-states BANNED/MANDATORY rules verbatim (search for Text(), AlertDialog, isPremiumProvider, AppLogger — should appear only as anchor references like AGENTS.md §2, not as re-enumerated rule text).
- checklist-template.md uses one consolidated checkbox per rule-family, not one item per rule.
- Project-specific structure (file paths, entities, tech stack versions) IS embedded — these are NOT in AGENTS.md.
- Total override word count drops by ~25–35% with no loss of actionable content.
Appendix — Quick reference: the layering contract
Layer 1 (AGENTS.md)        → always loaded → REFERENCE ONLY in templates
Layer 2 (docs/architecture)→ task-scoped   → LINK inline when relevant
Layer 3 (strategy/quality) → rarely        → LINK only for strategic sections

EMBED:   file paths, entities, tech stack, naming (NOT in AGENTS.md)
REFERENCE: banned/mandatory rules, principles, quality goals (IN AGENTS.md)
