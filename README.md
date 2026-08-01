# Spec-Kit Extended Flow

[![GitHub Release](https://img.shields.io/github/v/release/markuswondrak/spec-kit-extended-flow)](https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest)
[![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/markuswondrak/spec-kit-extended-flow/release-preset.yml)](https://github.com/markuswondrak/spec-kit-extended-flow/actions/workflows/release-preset.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<img width="1672" height="941" alt="extended-flow" src="https://github.com/user-attachments/assets/23828cb1-e05d-4227-a812-3f6254e4be5e" />

**A complete agentic engineering pipeline that turns intent into working, reviewed, documented software.** Built on [Spec-Kit](https://github.com/github/spec-kit), it extends the standard SDD workflow with deterministic quality gates and living documentation — so every feature that ships is reviewed for correctness *and* documented in sync with the code.

---

- [The Vision](#the-vision)
- [Quickstart](#quickstart)
- [Flows](#flows)
- [Reference](#reference)
- [Operations](#operations)
- [License](#license)

---

## The Vision

The standard Spec-Kit workflow is `specify → plan → tasks → implement`. That's a great start — but it treats implementation as the finish line. For a codebase that grows over time, that's a trap: every cycle adds code without systematic review, documentation drifts silently, and the project gets harder to reason about.

Extended Flow closes the loop. **Intent in, working software out — reviewed against the spec, documented in sync with the code, and shipped as a pull request.** Three principles drive the design:

- **Sustainable.** Every cycle leaves the project healthier. Specs are reviewed against implementation, documentation is reconciled with code, and conflicts are flagged for human resolution — never silently ignored.
- **Agentic.** The pipeline runs end-to-end with AI agents, but with deterministic guard rails and human gates at the right moments. When autonomy conflicts with safety, safety wins.
- **Pipeline.** Each stage feeds cleanly into the next. The output of `resolve-spec` becomes the input of `specify`. The output of `review` drives `fix`. The output of `documentation` feeds into `finish`. No guessing, no regex-based format detection, no silent failures.

| | Standard SDD | Extended Flow |
|---|---|---|
| After implementation | ✅ Done | 🔄 QA Review Loop |
| Documentation | Manual, drifts | Auto-reconciled per layer |
| Code-vs-docs conflicts | Silent | Flagged for human resolution |
| Issue → PR | Manual | Automated branch, commit, PR |

### How the principles become concrete

- **QA Review Loop.** A Review agent analyzes the implementation against the spec. If it finds critical issues, a Fix agent makes targeted corrections and the review runs again. This loops until the reviewer signs off with `PASS` — up to 5 iterations max.
- **Documentation Reconciliation.** After a passing review, a Documentation agent scans all implementation diffs and updates every documentation layer (global constraints, architecture decisions, interface contracts, AI debt register). **Code-vs-docs conflicts are flagged for human resolution — never auto-resolved.** This is a core invariant.
- **Issue → PR automation.** When started from a GitHub issue, the workflow automatically creates a feature branch, cleans up temporary files, commits all changes, and opens a pull request that closes the issue.

### A family of flows

Extended Flow ships a **family of composable flows** that share the same guard rails (QA review loop, safety caps, human gates) and the same documentation model. Today the family has three members:

- **Feature Flow** — the SDD lifecycle for new features (`specify → plan → tasks → implement → review → documentation → finish`).
- **Bugfix Flow** — a TDD lifecycle for surgical bugfixes (`analyze → test → fix → review → finish`), skipping spec/plan/tasks generation.
- **Quick Flow** — a lightweight pipeline for trivial, well-defined changes (`implement → review-fix → doc-check → finish`), no spec/plan/tasks, no human gates, self-fixing review in a single pass.

See [Flows](docs/flows.md) for the full diagrams and step-by-step breakdown. The family is designed to grow — future flows slot in as peers.

---

## Quickstart

```bash
# 1. Install the complete bundle (preset + extension + 3 workflows)
#
# Option A — For users (remote, from release ZIP)
#   The one-line `bundle install <id>` requires the bundle to be registered
#   in the Spec-Kit community catalog, which is not yet the case. Until then,
#   install the three components granularly:
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
specify extension add extendedflow --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/workflow.yml
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/bugfix-workflow.yml
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/quick-flow.yml

# Option B — For developers of this flow (local checkout)
#   Spec-Kit's bundle installer resolves extensions through the extension
#   catalog only, so the extension must be installed separately first:
specify extension add --dev .
specify bundle install .

# 2. Run the Feature Flow
specify workflow run spec-kit-extended-flow \
  --input spec="Build a REST API for managing todos with CRUD operations"
```

**What happens:** The workflow generates your spec, plan, and task list (with human approval gates at each stage), implements everything, runs QA review in a loop until PASS, then reconciles documentation.

### Bugfix Quickstart

The bundle installs all three workflows. Run the Bugfix Flow directly:

```bash
specify workflow run spec-kit-bugfix-flow \
  --input issue="42"
```

**What happens:** The workflow analyzes the bug, writes a failing test (RED), applies a surgical fix (GREEN), runs independent QA review in a loop until PASS, then commits and opens a PR.

### Quick Flow Quickstart

The bundle installs all three workflows. Run the Quick Flow directly:

```bash
# Run with a plain-text instruction
specify workflow run spec-kit-quick-flow \
  --input spec="Rename the login button label to Sign In"

# Or from a GitHub issue
specify workflow run spec-kit-quick-flow \
  --input issue="42"
```

**What happens:** The workflow implements the change directly from your instruction, runs a self-fixing review in a single pass, checks documentation impact, then commits and opens a PR. No spec/plan/tasks generation — ideal for label changes, message additions, and other trivial tweaks.

<details>
<summary><strong>Other input modes</strong></summary>

```bash
# From a spec file
specify workflow run spec-kit-extended-flow \
  --input file="./specs/todo-api.md"

# From a GitHub issue
specify workflow run spec-kit-extended-flow \
  --input issue="42"

# Bugfix from plain text
specify workflow run spec-kit-bugfix-flow \
  --input spec="The login endpoint returns 500 when password is empty"

# Quick Flow from plain text
specify workflow run spec-kit-quick-flow \
  --input spec="Rename the login button label to Sign In"
```

When started from a GitHub issue, the workflow also:
1. Creates a `feature/42-<slug>` or `fix/42-<slug>` branch from the issue title
2. Cleans up temporary files after completion
3. Commits all changes and opens a pull request that closes the issue

Quick Flow creates the same branch naming and uses `chore:` as the commit prefix.
</details>

<details>
<summary><strong>Manual installation (granular control)</strong></summary>

If you prefer to install preset, extension, and workflows separately:

```bash
# 1. Install preset (templates + scripts)
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip

# 2. Install extension (commands)
specify extension add extendedflow --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip

# 3. Install workflows
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/workflow.yml
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/bugfix-workflow.yml
specify workflow add .specify/presets/spec-kit-extended-flow/workflows/quick-flow.yml
```
</details>

<details>
<summary><strong>Local development</strong></summary>

For development on a checkout of this repository, use the two-step process:

```bash
# 1. Install the extension locally (dev mode)
specify extension add --dev .

# 2. Install the bundle (extension is skipped as already installed)
specify bundle install .
```

**Why two steps?** Spec-Kit's bundle installer resolves extensions through the extension catalog only (not from the bundle directory). Until this bundle is published to the community catalog, the extension must be installed separately first. The bundle installer then detects it as already present and skips it. See [Spec-Kit #3058](https://github.com/github/spec-kit/issues/3058) for the design rationale.
</details>

---

## Flows

Extended Flow is a family of composable flows. Each flow is a self-contained pipeline with its own steps, gates, and review loop — but all flows share the same guard rails, documentation model, and issue-to-PR automation.

### Feature Flow

The SDD lifecycle for new features. Generates spec, plan, and tasks, implements them, runs a QA review loop, reconciles documentation, and ships a PR. See [docs/flows.md](docs/flows.md#feature-flow) for the full diagram and step table.

### Bugfix Flow

A TDD lifecycle for surgical bugfixes. Skips spec/plan/tasks generation and follows a **RED-GREEN-REVIEW** cycle, then ships a PR. See [docs/flows.md](docs/flows.md#bugfix-flow) for the full diagram and step table.

### Quick Flow

A lightweight pipeline for trivial, well-defined changes. Skips spec/plan/tasks entirely and uses a **self-fixing review** in a single pass. See [docs/flows.md](docs/flows.md#quick-flow) for the full diagram and step table.

---

## Reference

### Spec Input Parameters

Both flows accept three input parameters. At least one must be provided. If multiple are provided, their contents are concatenated.

| Parameter | Type | Example | How it works |
|-----------|------|---------|--------------|
| `spec` | Plain text | `--input spec="Build a user auth system with OAuth"` | Passed directly to `speckit.specify` |
| `file` | File path | `--input file="./specs/feature.md"` | File content is read and passed as the spec |
| `issue` | Issue number | `--input issue="42"` | Issue title + body fetched via `gh` CLI |

**GitHub issues** require `gh` CLI installed and authenticated. **File input** must exist relative to your working directory.

### Individual Commands

Run these standalone outside the workflows:

| Command | Purpose |
|---------|---------|
| `/speckit.extendedflow.review` | QA review only |
| `/speckit.extendedflow.documentation` | Documentation reconciliation only |
| `/speckit.extendedflow.documentation-init` | Bootstrap documentation for an existing project |
| `/speckit.extendedflow.finish` | Cleanup, commit, and PR (post-implementation) |
| `/speckit.extendedflow.quick-implement` | Direct implementation for trivial changes |
| `/speckit.extendedflow.quick-review` | Self-fixing review (review + fix in one pass) |
| `/speckit.extendedflow.doc-check` | Lightweight documentation impact check |

For architecture, component map, design principles, and customization options, see [docs/reference.md](docs/reference.md).

---

## Operations

### Prerequisites

Run these **before** the first workflow — they set up your project's foundation:

```bash
# 1. Initialize Spec-Kit (if not already done)
specify init

# 2. Establish project constitution (governing principles)
/speckit.constitution Create principles focused on code quality, testing standards, and performance

# 3. Tailor templates to your project (also handles the git-extension incompatibility)
/speckit.extendedflow.project-init

# 4. (Optional) Bootstrap documentation for existing projects
/speckit.extendedflow.documentation-init
```

The workflows assume your project is already initialized and has a constitution in place. The plan step infers tech stack/architecture from your existing project — no planning constraints input needed at runtime.

`speckit.extendedflow.project-init` analyzes your codebase, generates project-specific template overrides, and **automatically disables spec-kit's git extension** to prevent the incompatibility described in [docs/troubleshooting.md](docs/troubleshooting.md#git-extension-compatibility).

For common issues, installation notes, and the git extension compatibility details, see [docs/troubleshooting.md](docs/troubleshooting.md). For release instructions, see [docs/releasing.md](docs/releasing.md).

---

## License

MIT
