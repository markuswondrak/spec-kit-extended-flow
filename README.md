# Spec-Kit Extended Flow

A [Spec-Kit](https://github.com/github/spec-kit) preset that adds a strict QA review loop and automated documentation reconciliation to the standard SDD workflow.

## Idea

The standard Spec-Kit workflow (`specify → plan → tasks → implement`) is a great start, but it stops at implementation. **Spec-Kit Extended Flow** adds two critical layers:

1. **QA Review Loop** — After implementation, a Reviewer agent analyzes the code against your spec. If it finds critical issues, implementation is re-triggered automatically with the findings as context. This loops until the reviewer signs off with `PASS` (or a max of 5 iterations).

2. **Documentation Reconciliation** — After a successful review, a Documentation agent scans all implementation diffs and updates every documentation layer (global constraints, architecture decisions, interface contracts, AI debt register). Code-vs-docs conflicts are flagged for human resolution — never auto-resolved.

The result: every feature that ships through this workflow has been reviewed for correctness AND its documentation stays in sync with the code.

## Quickstart

```bash
# 1. Install the latest published preset ZIP
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip

# Or pin a specific release
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/download/v2.1.0/spec-kit-extended-flow.zip

# 2. Install the workflow
specify workflow add .specify/presets/spec-kit-extended-flow/workflow.yml

# 3. Run it — plain text spec
specify workflow run spec-kit-extended-flow \
  --input spec="Build a REST API for managing todos with CRUD operations"

# Or from a file
specify workflow run spec-kit-extended-flow \
  --input file="./specs/todo-api.md"

# Or from a GitHub issue in this repository
specify workflow run spec-kit-extended-flow \
  --input issue="42"
```

**What happens:** The workflow generates your spec, plan, and task list (with human approval gates at each stage), implements everything, runs QA review in a loop until PASS, then reconciles documentation.

## Prerequisites

Run these BEFORE the workflow — they set up your project's foundation:

```bash
# 1. Establish project constitution (governing principles)
/speckit.constitution Create principles focused on code quality, testing standards, and performance

# 2. (Optional) Bootstrap documentation for existing projects
/speckit.extendedflow.documentation-init
```

The workflow assumes your project is already initialized (`specify init`) and has a constitution in place. The plan step infers tech stack/architecture from your existing project — no planning constraints input needed at runtime.

## Installation notes

`specify preset add --from` expects a ZIP package URL. Do not pass the GitHub repository landing page URL; that downloads HTML, not a preset package.

For local development from a checkout of this repository, use:

```bash
specify preset add --dev .
```

Release packages are built as `dist/spec-kit-extended-flow.zip` by `scripts/package-preset.sh` and published as GitHub Release assets by `.github/workflows/release-preset.yml`.

## Spec Input Parameters

The workflow accepts three separate input parameters. At least one must be provided. If multiple are provided, their contents are concatenated.

| Parameter | Type | Example | How it works |
|-----------|------|---------|--------------|
| `spec` | Plain text | `--input spec="Build a user auth system with OAuth"` | Passed directly to `speckit.specify` |
| `file` | File path | `--input file="./specs/feature.md"` | File content is read and passed as the spec |
| `issue` | Issue number | `--input issue="42"` | Issue title + body are fetched from the current repository via `gh` CLI and passed as the spec |

**Requirements for GitHub issues:** The `gh` CLI must be installed and authenticated (`gh auth login`). Only issues from the repository the workflow is running in are supported.

**Requirements for file input:** The file must exist relative to your current working directory.

## Workflow Steps

```
resolve-spec  →  specify  →  [gate]  →  plan  →  [gate]  →  tasks  →  [gate]
                                                                         ↓
                                                            ┌── implement ←──┐
                                                            ↓                │
                                                          review ── FAIL ────┘
                                                            │
                                                          PASS
                                                            ↓
                                                         [gate]
                                                            ↓
                                                      documentation
                                                            ↓
                                                          done
```

| Step | Type | Description |
|------|------|-------------|
| `resolve-spec` | shell | Resolves file paths and GitHub issues to spec content |
| `specify` | command | Generates the specification from your input |
| `spec-gate` | gate | Human approval before planning |
| `plan` | command | Creates implementation plan (infers from project) |
| `plan-gate` | gate | Human approval before task generation |
| `tasks` | command | Generates actionable task breakdown |
| `tasks-gate` | gate | Human approval before implementation |
| `qa-loop` | do-while | Implementation + review loop (max 5 iterations) |
| `review-gate` | gate | Human approval after QA pass |
| `doc-reconcile` | command | Updates all documentation layers |

**Safety caps:** Review loop maxes out at 5 iterations. Human gates let you inspect and approve each phase. Workflow state is persisted — resume from any interruption with `specify workflow resume <run_id>`.

## Individual Commands

Run these standalone outside the workflow:

```bash
# QA review only
/speckit.extendedflow.reviewer

# Documentation reconciliation only
/speckit.extendedflow.documentation

# Bootstrap documentation for an existing project
/speckit.extendedflow.documentation-init
```

## Architecture

| Component | File | Role |
|-----------|------|------|
| Preset manifest | `preset.yml` | Registers commands and templates |
| Workflow | `workflow.yml` | Orchestrates the lifecycle |
| Reviewer | `commands/speckit.extendedflow.reviewer.md` | QA agent system prompt |
| Documentation | `commands/speckit.extendedflow.documentation.md` | Doc agent system prompt |
| Documentation init | `commands/speckit.extendedflow.documentation-init.md` | Doc bootstrap agent |
| Review template | `templates/review-findings.md` | Structured review output |
| Doc template | `templates/documentation.md` | Structured doc output |
| Doc init template | `templates/documentation-init.md` | Init report template |

## Customization

Override templates and adjust review strictness by copying files to `.specify/templates/overrides/`. See the [preset.yml](./preset.yml) for the full list of overridable templates.

Stack with other presets using priority ordering:

```bash
specify preset add healthcare-compliance --priority 10
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip --priority 5
```

## Troubleshooting

**Reviewer always returns FAIL:** Check `.specify/spec.md` is up to date. Review findings in `review-findings.md`. Adjust `max_iterations` in `workflow.yml` if needed.

**Workflow stuck in loop:** Check `specify workflow status`. The cap of 5 iterations prevents infinite loops.

**Workflow not found by ID:** Install it: `specify workflow add .specify/presets/spec-kit-extended-flow/workflow.yml`

**GitHub issue not resolving:** Ensure `gh` CLI is installed and authenticated (`gh auth status`). The `issue` parameter only supports issues from the current repository (bare number, e.g., `42`). Cross-repo references and full URLs are not supported.

**Commands not appearing:** Reinstall the preset: `specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip`

## License

MIT
