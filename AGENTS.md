# Spec-Kit Extended Flow — Global Constraints

This is a **Spec-Kit preset, extension, and bundle**, not an application. It defines workflows (`workflows/`), a preset manifest (`preset.yml`), an extension manifest (`extension.yml`), a bundle manifest (`bundle.yml`), agent commands (`commands/`), templates (`templates/`), and Python runtime scripts plus shell tooling (`scripts/`). All changes must preserve the Spec-Kit contract.

## Hard Prohibitions

1. **NEVER break the downstream contract.** `resolve-spec` output must always feed `speckit.specify` via `steps.resolve-spec.output.stdout`. Any refactor of input resolution must preserve this interface.
2. **NEVER use regex-based format detection for inputs.** Each input parameter (`spec`, `file`, `issue`) has exactly one responsibility. No guessing, no fallthrough logic.
3. **NEVER auto-resolve code-vs-documentation conflicts.** Flag them for human resolution. This is a core invariant of the documentation reconciler.

## Quality Goals

1. **Adoptability.** The preset must be easy to start with, easy to understand, and easy to customize. A developer goes from install to first run in minutes. The mental model is simple: spec in, reviewed and documented implementation out. Components compose with other presets and don't impose opinions that conflict with the user's project. When adoptability conflicts with completeness, choose the simpler path.

2. **Verifiable safety.** Every guard rail must be deterministic and inspectable. Verdict extraction, input validation, conflict flagging, and format checks produce reproducible outcomes. When the pipeline passes, fails, or flags a conflict, the user can understand why without reading source code. Human gates are available as a fallback but should not be required for correct results. When safety conflicts with autonomy, safety wins.

3. **Autonomous operation.** The pipeline runs end-to-end without human intervention. Each step produces correct output given correct input, and the system self-corrects through the standard convergence loop. The end goal: spec in, reviewed and documented implementation out, no human in the loop. When autonomy conflicts with adoptability, adoptability wins (a tool nobody uses correctly gains nothing from being fully autonomous).

## Project Structure

| Path | Role |
|------|------|
| `workflows/workflow.yml` | Orchestration: inputs, steps, gates, loops for feature development |
| `workflows/bugfix-workflow.yml` | Orchestration: standard bug commands, assessment gate, and issue-to-PR finish |
| `workflows/quick-flow.yml` | Orchestration: lightweight pipeline for trivial changes (no spec/plan/tasks) |
| `preset.yml` | Preset manifest: templates, scripts, version, tags |
| `extension.yml` | Extension manifest: commands, version, tags |
| `bundle.yml` | Bundle manifest: composes preset + extension + workflows into a single install unit |
| `scripts/` | Python 3 stdlib runtime and repository-maintenance scripts |
| `commands/` | Agent system prompts (documentation, documentation-init, finish, quick-implement, quick-review, doc-check) |
| `templates/` | Structured output templates (review-findings, documentation) |
| `tests/` | Python stdlib unittest suites for runtime scripts and workflow structure |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/resolve-spec.py` | Reads `spec`, `file`, and `issue` from the run's `inputs.json` and resolves them into specification/bug-report content (persisted to `resolved-spec.txt`) |
| `scripts/create-branch.py` | Reads the issue from the run's `inputs.json` and creates a `<prefix>/<issue>-<slug>` branch (default prefix: `feature`, bugfix prefix: `fix`) |
| `scripts/check-converge.py` | Detects whether `speckit.converge` appended new tasks (standard Spec-Kit convergence loop) |
| `scripts/extract-verdict.py` | Extracts the Quick Flow review verdict from the review findings filename |
| `scripts/resolve-bug-context.py` | Records the standard bug extension's active bug directory in `feature.json` |
| `scripts/check-bug-verdict.py` | Validates the standard bug extension's `test.md` result |
| `scripts/init-quick.py` | Reads the run's `inputs.json`/`resolved-spec.txt` and creates or reuses a Quick Flow feature directory and `feature.json` pointer (`type: "quick"`) |
| `scripts/resolve-pr-template.py` | Discovers a pull-request template in the downstream project using GitHub-standard search paths |
| `scripts/package-preset.py` | Builds the preset ZIP package |
| `scripts/build-catalog.py` | Builds deterministic project-owned HTTPS catalog archives under `catalog/artifacts/` and syncs catalog version pins |
| `scripts/release-version.py` | Bumps every component (manifests, `bundle.yml` pins, `workflows/*.yml`) to one version, regenerates the catalog, commits, and tags |
| `scripts/release.py` | Merges a release branch, bumps the minor version, tags, and pushes |
| `scripts/check-release.py` | Validates that one version is consistent across manifests, workflows, catalogs, and (with `--artifacts`) built archives |

## Downstream Project Layout

This repo is a **preset, extension, and bundle**. The agents in `commands/` and the workflows in `workflows/` execute in **downstream projects** that install this bundle via `specify bundle install` (or the preset/extension individually via `specify preset add` / `specify extension add`). The downstream file layout is completely different from this repo.

Downstream runtime requires `python3` on `PATH`; workflow and command runtime call sites use `python3 .specify/presets/spec-kit-extended-flow/scripts/<name>.py`. Windows runtime execution has not been verified, and this does not claim Windows support.

### Downstream root

```
AGENTS.md                    ← Points to current plan (updated by speckit.plan)
specs/                       ← Feature directories, one per feature item
  <NNN>-<feature-name>/
    spec.md                  ← Generated by speckit.specify
    plan.md                  ← Generated by speckit.plan
    tasks.md                 ← Generated by speckit.tasks; extended by speckit.converge
    research.md              ← Generated by speckit.plan (Phase 0)
    data-model.md            ← Generated by speckit.plan (Phase 1)
    quickstart.md            ← Generated by speckit.plan (Phase 1)
    contracts/               ← Generated by speckit.plan (Phase 1)
    checklists/              ← Generated by speckit.specify
  .specify/bugs/<slug>/
    assessment.md            ← Generated by speckit.bug.assess
    fix.md                   ← Generated by speckit.bug.fix
    test.md                  ← Generated by speckit.bug.test
  <issue>-quick-<slug>/
    instruction.md           ← Written by speckit.extendedflow.quick-implement
    review-findings.md       ← QA review output (generated by quick-review)
    doc-check.md             ← Documentation check report (generated by doc-check)
```

### `.specify/` directory (downstream)

| Path | Type | Purpose |
|------|------|---------|
| `extensions.yml` | Installed config | Hook registration (before/after each command) |
| `extensions/` | Installed config | Extension implementations (git, agent-context) |
| `bugs/<slug>/` | Run artifact | Standard Spec-Kit bug reports and verification records |
| `feature.json` | Run artifact | Current feature directory pointer |
| `init-options.json` | Installed config | Init configuration (AI, numbering, integration) |
| `memory/constitution.md` | Persistent | Project constitution |
| `presets/` | Installed config | Installed presets (including this one) |
| `scripts/bash/` | Installed config | Core spec-kit scripts |
| `templates/` | Installed config | Core templates (spec, plan, tasks, etc.) |
| `workflows/<id>/workflow.yml` | Installed config | Workflow definitions |
| `workflows/runs/<run_id>/` | Engine-owned | Run state, inputs, logs — **must never be deleted** |

**Installed config** must never be touched by cleanup. **Run artifacts** may be cleaned after documentation reconciliation. The workflow run directory (`.specify/workflows/runs/<run_id>/`) is **not** a cleanable run artifact: it is owned by the Spec-Kit engine, which writes `state.json` there after the `finish` step returns. Deleting it crashes the run at the end with an unhandled `FileNotFoundError`.

### Cleanup scope (post-documentation reconciliation)

Safe to remove:
- `specs/<NNN>-<feature-name>/` — entire feature directory (spec, plan, tasks, research, data-model, quickstart, contracts, checklists)
- `.specify/bugs/<slug>/` — entire bugfix directory (assessment, fix, test)
- `specs/<issue>-quick-<slug>/` — entire quick directory (instruction, review-findings, doc-check)
- `.specify/feature.json` — current feature pointer

Must preserve:
- `.specify/presets/`, `.specify/templates/`, `.specify/scripts/`, `.specify/extensions/`, `.specify/extensions.yml`, `.specify/init-options.json`, `.specify/memory/`, `.specify/workflows/<id>/workflow.yml`
- `.specify/workflows/runs/<run_id>/` — engine-owned run state (deleting it crashes the engine)

## Glossary

- **SDD**: Specification-Driven Development — the core methodology this preset extends.
- **Bundle**: A Spec-Kit meta-manifest (`bundle.yml`) that composes presets, extensions, steps, and workflows into a single, versioned, role-oriented install unit.
- **Convergence Loop**: The `do-while` iteration of `speckit.converge → check → speckit.implement` in the Feature Flow that runs until converge appends no new tasks or max 5 iterations. Built entirely on the standard Spec-Kit `speckit.converge` command.
- **Doc Reconciliation**: The post-implementation step that updates layered documentation and flags code-vs-docs conflicts.
- **Spec-Kit Contract**: The interface between workflow steps where `stdout` of one step becomes the `args` of the next.
- **Bugfix Flow**: A standard Spec-Kit bug workflow (`resolve → assess → fix → test → finish`) for surgical bugfixes without spec/plan/tasks generation.
- **Quick Flow**: A lightweight workflow (`resolve → init-quick → implement → review-fix → doc-check → finish`) for trivial, well-defined changes (label renames, message additions). No spec/plan/tasks generation, no human gates, self-fixing review in a single pass.

## Known Issues

- **Spec-Kit < v0.9.5 registration bug**: Previously, preset commands with three-part names (`speckit.extendedflow.*`) were silently dropped during `specify preset add`. This is no longer an issue — commands are now delivered via the extension (`extension.yml`), which is the correct Spec-Kit architecture. The preset delivers templates, scripts, and the unattended runtime preamble, which is composed (as a `prepend` command override) onto every non-interactive core, bug, and Extended-Flow command the flows invoke. The interactive bootstrap commands (`project-init`, `documentation-init`) are intentionally excluded.

## Pointers to Depth

- **Workflow steps & gates**: See `workflows/workflow.yml` (feature flow), `workflows/bugfix-workflow.yml` (bugfix flow), and `workflows/quick-flow.yml` (quick flow)
- **Agent behaviors**: See `commands/speckit.extendedflow.documentation.md`, `commands/speckit.extendedflow.finish.md`, `commands/speckit.extendedflow.quick-implement.md`, `commands/speckit.extendedflow.quick-review.md`, `commands/speckit.extendedflow.doc-check.md`, plus the standard `speckit.bug.assess`, `speckit.bug.fix`, and `speckit.bug.test` commands from Spec-Kit's `bug` extension. The Feature Flow's QA loop uses the standard `speckit.analyze` and `speckit.implement`/`speckit.converge` commands.
- **Output templates**: See `templates/review-findings.md`, `templates/documentation.md`
- **Input resolution logic**: See `scripts/resolve-spec.py`
- **Branch creation and verdict extraction**: See `scripts/create-branch.py`, `scripts/check-converge.py`, `scripts/extract-verdict.py`, `scripts/resolve-bug-context.py`, `scripts/check-bug-verdict.py`
- **PR template resolution**: See `scripts/resolve-pr-template.py`
- **Bundle composition**: See `bundle.yml`
- **Architecture & design rationale**: See `README.md`
