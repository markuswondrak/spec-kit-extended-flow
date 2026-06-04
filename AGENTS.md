# Spec-Kit Extended Flow — Global Constraints

This is a **Spec-Kit preset**, not an application. It defines a workflow (`workflow.yml`), a manifest (`preset.yml`), agent commands (`commands/`), templates (`templates/`), and shell scripts (`scripts/`). All changes must preserve the Spec-Kit contract.

## Hard Prohibitions

1. **NEVER break the downstream contract.** `resolve-spec` output must always feed `speckit.specify` via `steps.resolve-spec.output.stdout`. Any refactor of input resolution must preserve this interface.
2. **NEVER use regex-based format detection for inputs.** Each input parameter (`spec`, `file`, `issue`) has exactly one responsibility. No guessing, no fallthrough logic.
3. **NEVER auto-resolve code-vs-documentation conflicts.** Flag them for human resolution. This is a core invariant of the documentation reconciler.

## Quality Goals

1. **Testability over convenience.** Shell logic lives in external scripts (`scripts/`), not inline in YAML. Every script must be independently executable and testable.
2. **Fail fast with context.** Missing files, missing CLI tools, failed fetches, and empty inputs must exit non-zero with a descriptive `ERROR:` message to stderr.
3. **Backward compatibility.** Optional inputs must have sensible defaults (`""`). Removing an input is a breaking change requiring a major version bump.

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
