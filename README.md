# Spec-Kit Extended Flow

[![GitHub Release](https://img.shields.io/github/v/release/markuswondrak/spec-kit-extended-flow)](https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/markuswondrak/spec-kit-extended-flow/release-preset.yml)](https://github.com/markuswondrak/spec-kit-extended-flow/actions/workflows/release-preset.yml)

<img width="1672" height="941" alt="extended-flow" src="https://github.com/user-attachments/assets/23828cb1-e05d-4227-a812-3f6254e4be5e" />

A [Spec-Kit](https://github.com/github/spec-kit) preset that adds a strict QA review loop and automated documentation reconciliation to the standard SDD workflow.

## Idea

The standard Spec-Kit workflow (`specify → plan → tasks → implement`) is a great start, but it stops at implementation. **Spec-Kit Extended Flow** adds two critical layers:

1. **QA Review Loop** — After implementation, a Review agent analyzes the code against your spec. If it finds critical issues, implementation is re-triggered automatically with the findings as context. This loops until the review signs off with `PASS` (or a max of 5 iterations).

2. **Documentation Reconciliation** — After a successful review, a Documentation agent scans all implementation diffs and updates every documentation layer (global constraints, architecture decisions, interface contracts, AI debt register). Code-vs-docs conflicts are flagged for human resolution — never auto-resolved.

The result: every feature that ships through this workflow has been reviewed for correctness AND its documentation stays in sync with the code.

## Quickstart

```bash
# 1. Install the preset (templates + scripts)
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip

# 2. Install the extension (commands)
specify extension add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip

# Or pin a specific release
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/download/v2.1.0/spec-kit-extended-flow.zip
specify extension add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/download/v2.1.0/spec-kit-extended-flow.zip

# 3. Install the workflow
specify workflow add .specify/presets/spec-kit-extended-flow/workflow.yml

# 4. Run it — plain text spec
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

When started from a GitHub issue (`--input issue="42"`), the workflow also:
1. Creates a `feature/42-<slug>` branch from the issue title
2. Cleans up temporary files (specs, feature pointer, workflow run state) after documentation reconciliation
3. Commits all changes and opens a pull request that closes the issue

## Prerequisites

Run these BEFORE the workflow — they set up your project's foundation:

```bash
# 1. Establish project constitution (governing principles)
/speckit.constitution Create principles focused on code quality, testing standards, and performance

# 2. (Optional) Bootstrap documentation for existing projects
/speckit.extendedflow.documentation-init
```

The workflow assumes your project is already initialized (`specify init`) and has a constitution in place. The plan step infers tech stack/architecture from your existing project — no planning constraints input needed at runtime.

### Git Extension Compatibility

This workflow manages its own branch creation (issue-based naming: `feature/<issue>-<slug>`) and conflicts with spec-kit's built-in git extension, which uses sequential numbering (`001-<slug>`) via a `before_specify` hook.

**Before running this workflow, disable the git extension:**

```bash
specify extension disable git
```

**Why this is necessary:**
- The git extension registers a mandatory `before_specify` hook (`speckit.git.feature`) that creates branches with sequential numbering
- Our workflow creates branches with issue-based naming via `create-branch.sh`
- On integrations that do not support the `EXECUTE_COMMAND` protocol (e.g., opencode), the mandatory hook causes the agent to hang waiting for a result that never comes
- Disabling the git extension eliminates the conflict and allows the workflow to manage branching consistently

**What you lose:**
- Auto-commits after each SDD step (these are optional and disabled by default anyway)
- `speckit.git.feature` command (our workflow handles branch creation instead)

**What you keep:**
- All core spec-kit commands (`speckit.specify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`)
- All extended flow commands (`speckit.extendedflow.review`, `speckit.extendedflow.fix`, etc.)
- Issue-to-PR automation via the `finish` command

To re-enable the git extension later:
```bash
specify extension enable git
```

## Installation notes

`specify preset add --from` expects a ZIP package URL. The same applies to `specify extension add --from`. Do not pass the GitHub repository landing page URL; that downloads HTML, not a preset package.

For local development of a checkout of this repository, use:

```bash
specify preset add --dev .
specify extension add --dev .
```

Release packages are built as `dist/spec-kit-extended-flow.zip` by `scripts/package-preset.sh` and published as GitHub Release assets by `.github/workflows/release-preset.yml`.

## Releasing

To cut a new release, run the release script from the repository root:

```bash
scripts/release-version.sh 1.2.3
```

This will:
1. Validate the version format (semver: `MAJOR.MINOR.PATCH`)
2. Update the `version` field in `preset.yml` and `extension.yml`
3. Commit the version bump
4. Create an annotated git tag (`v1.2.3`)

Then push the tag to trigger the GitHub Actions release workflow:

```bash
git push origin main --tags
```

The release workflow (`.github/workflows/release-preset.yml`) will build the preset package and publish it as a GitHub Release asset.

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
resolve-spec  →  [branch*]  →  specify  →  [gate]  →  plan  →  [gate]  →  tasks  →  [gate]
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
                                                                        finish
                                                                          ↓
                                                                        done
```
\* `create-branch` only when started from a GitHub issue (`--input issue="..."`).
\* `finish` always runs: cleans up temporary files, commits changes, and opens a PR when an issue was provided.

| Step | Type | Description |
|------|------|-------------|
| `resolve-spec` | shell | Resolves file paths and GitHub issues to spec content |
| `create-branch` | shell | *(issue only)* Creates `feature/<issue>-<slug>` branch from issue title |
| `specify` | command | Generates the specification from your input |
| `spec-gate` | gate | Human approval before planning |
| `plan` | command | Creates implementation plan (infers from project) |
| `plan-gate` | gate | Human approval before task generation |
| `tasks` | command | Generates actionable task breakdown |
| `qa-loop` | do-while | Implementation + review loop (max 5 iterations) |
| `documentation` | command | Updates all documentation layers |
| `finish` | command | Cleans up temporary files, commits changes, opens PR when issue provided |

**Safety caps:** Review loop maxes out at 5 iterations. Human gates let you inspect and approve each phase. Workflow state is persisted — resume from any interruption with `specify workflow resume <run_id>`.

## Individual Commands

Run these standalone outside the workflow:

```bash
# QA review only
/speckit.extendedflow.review

# Documentation reconciliation only
/speckit.extendedflow.documentation

# Bootstrap documentation for an existing project
/speckit.extendedflow.documentation-init

# Cleanup, commit, and PR (post-implementation finish)
/speckit.extendedflow.finish
```

## Architecture

| Component | File | Role |
|-----------|------|------|
| Preset manifest | `preset.yml` | Registers templates and scripts |
| Extension manifest | `extension.yml` | Registers commands (agent system prompts) |
| Workflow | `workflow.yml` | Orchestrates the lifecycle |
| Review | `commands/speckit.extendedflow.review.md` | QA agent system prompt |
| Fix | `commands/speckit.extendedflow.fix.md` | Fix agent system prompt |
| Documentation | `commands/speckit.extendedflow.documentation.md` | Doc agent system prompt |
| Documentation init | `commands/speckit.extendedflow.documentation-init.md` | Doc bootstrap agent |
| Project init | `commands/speckit.extendedflow.project-init.md` | Project analysis agent |
| Finish | `commands/speckit.extendedflow.finish.md` | Cleanup, commit, and PR agent |
| Review template | `templates/review-findings.md` | Structured review output |
| Doc template | `templates/documentation.md` | Structured doc output |
| Resolve spec | `scripts/resolve-spec.sh` | Resolves spec/file/issue inputs |
| Create branch | `scripts/create-branch.sh` | Creates feature branch from issue |
| Verify spec | `scripts/verify-spec.sh` | Validates that speckit.specify created a spec file |
| Extract verdict | `scripts/extract-verdict.sh` | Extracts QA review verdict from findings filename |

## Customization

Override templates and adjust review strictness by copying files to `.specify/templates/overrides/`. See the [preset.yml](./preset.yml) for the full list of overridable templates.

Stack with other presets using priority ordering:

```bash
specify preset add healthcare-compliance --priority 10
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip --priority 5
```

## Troubleshooting

**Reviewer always returns FAIL:** Check `.specify/spec.md` is up to date. Review findings are inside the current feature directory (`specs/<NNN>-<feature>/review-findings.md`). Adjust `max_iterations` in `workflow.yml` if needed.

**Workflow stuck in loop:** Check `specify workflow status`. The cap of 5 iterations prevents infinite loops.

**Workflow not found by ID:** Install it: `specify workflow add .specify/presets/spec-kit-extended-flow/workflow.yml`

**GitHub issue not resolving:** Ensure `gh` CLI is installed and authenticated (`gh auth status`). The `issue` parameter only supports issues from the current repository (bare number, e.g., `42`). Cross-repo references and full URLs are not supported.

**Commands not appearing:** Ensure both the preset and extension are installed:
```bash
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
specify extension add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
```

**No spec created after specify step (specs/ is empty):** This happens when the git extension's `before_specify` hook tries to execute via `EXECUTE_COMMAND`, but the integration does not support it (e.g., opencode). The agent hangs waiting for the hook result, and the spec is never written. The workflow includes a `verify-spec` safety net that catches this and aborts with a clear error. To fix: disable the git extension before running the workflow: `specify extension disable git`. See [Git Extension Compatibility](#git-extension-compatibility) above.

## License

MIT
