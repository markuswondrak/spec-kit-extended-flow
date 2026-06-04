# Spec-Kit Extended Flow — Global Constraints

This is a **Spec-Kit preset**, not an application. It defines a workflow (`workflow.yml`), a manifest (`preset.yml`), agent commands (`commands/`), templates (`templates/`), and shell scripts (`scripts/`). All changes must preserve the Spec-Kit contract.

## Hard Prohibitions

1. **NEVER break the downstream contract.** `resolve-spec` output must always feed `speckit.specify` via `steps.resolve-spec.output.stdout`. Any refactor of input resolution must preserve this interface.
2. **NEVER use regex-based format detection for inputs.** Each input parameter (`spec`, `file`, `issue`) has exactly one responsibility. No guessing, no fallthrough logic.
3. **NEVER auto-resolve code-vs-documentation conflicts.** Flag them for human resolution. This is a core invariant of the documentation reconciler.

## Quality Goals

1. **Adoptability.** The preset must be easy to start with, easy to understand, and easy to customize. A developer goes from install to first run in minutes. The mental model is simple: spec in, reviewed and documented implementation out. Components compose with other presets and don't impose opinions that conflict with the user's project. When adoptability conflicts with completeness, choose the simpler path.

2. **Verifiable safety.** Every guard rail must be deterministic and inspectable. Verdict extraction, input validation, conflict flagging, and format checks produce reproducible outcomes. When the pipeline passes, fails, or flags a conflict, the user can understand why without reading source code. Human gates are available as a fallback but should not be required for correct results. When safety conflicts with autonomy, safety wins.

3. **Autonomous operation.** The pipeline runs end-to-end without human intervention. Each step produces correct output given correct input, and the system self-corrects through the QA loop. The end goal: spec in, reviewed and documented implementation out, no human in the loop. When autonomy conflicts with adoptability, adoptability wins (a tool nobody uses correctly gains nothing from being fully autonomous).

## Project Structure

| Path | Role |
|------|------|
| `workflow.yml` | Orchestration: inputs, steps, gates, loops |
| `preset.yml` | Manifest: version, provides, tags |
| `scripts/` | Executable shell scripts called by workflow steps |
| `commands/` | Agent system prompts (reviewer, documentation, documentation-init) |
| `templates/` | Structured output templates (review-findings, documentation, documentation-init) |
| `tests/` | Bash test suites for shell scripts and workflow structure |

## Glossary

- **SDD**: Specification-Driven Development — the core methodology this preset extends.
- **QA Loop**: The `do-while` iteration of `implement → review → verdict` that runs until PASS or max 5 iterations.
- **Doc Reconciliation**: The post-implementation step that updates layered documentation and flags code-vs-docs conflicts.
- **Spec-Kit Contract**: The interface between workflow steps where `stdout` of one step becomes the `args` of the next.

## Pointers to Depth

- **Workflow steps & gates**: See `workflow.yml`
- **Agent behaviors**: See `commands/speckit.extendedflow.reviewer.md`, `commands/speckit.extendedflow.documentation.md`
- **Output templates**: See `templates/review-findings.md`, `templates/documentation.md`
- **Input resolution logic**: See `scripts/resolve-spec.sh`
- **Architecture & design rationale**: See `README.md`
