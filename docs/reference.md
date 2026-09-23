# Reference

## Architecture

Extended Flow is delivered as **three artifacts bundled together** — a preset (templates + scripts + unattended runtime preamble), an extension (commands), and four workflows — following the Spec-Kit separation of concerns. The bundle also declares Spec-Kit's built-in `bug` extension (`bug` v1.0.0) as a dependency, so the standard bug commands install with it.

| Package | Manifest | Delivers | Installed via |
|---------|----------|----------|---------------|
| **Bundle** | `bundle.yml` | Preset + Extension + `bug` extension + Workflows (meta-manifest) | `specify bundle install` |
| Preset | `preset.yml` | Templates, scripts, unattended runtime preamble | `specify preset add` |
| Extension | `extension.yml` | Commands (agent prompts) | `specify extension add` |
| Workflow | `workflows/*.yml` | Step orchestration | `specify workflow add` |

The bundle installs the `bug` dependency automatically. For a standalone workflow install, add it first with `specify extension add bug`.

This split exists because Spec-Kit's architecture reserves commands for extensions. Presets provide output formats; extensions provide agent behaviors. The bundle acts as a **facade** that composes all three into a single install operation while preserving the ability to install them individually for granular control.

### Key Design Principles

- **Deterministic safety.** Verdict extraction, input validation, conflict flagging, and format checks produce reproducible outcomes. When the pipeline passes, fails, or flags a conflict, you can understand why without reading source code.
- **Human gates as fallback, not requirement.** Every guard rail is deterministic and inspectable. Human gates are available but not required for correct results.
- **Never auto-resolve code-vs-docs conflicts.** The documentation reconciler flags contradictions for human resolution. This is a core invariant.
- **Single-responsibility inputs.** Each input parameter (`spec`, `file`, `issue`) has exactly one resolution strategy. No regex-based format detection, no guessing.

### Component Map

| Component | File | Role |
|-----------|------|------|
| Documentation agent | `commands/speckit.extendedflow.documentation.md` | Doc reconciliation agent prompt |
| Documentation init | `commands/speckit.extendedflow.documentation-init.md` | Doc bootstrap agent prompt |
| Project init | `commands/speckit.extendedflow.project-init.md` | Project analysis + template tailoring agent prompt |
| Finish agent | `commands/speckit.extendedflow.finish.md` | Cleanup, commit, PR agent prompt |
| Quick implement | `commands/speckit.extendedflow.quick-implement.md` | Direct implementation agent for trivial changes |
| Quick review | `commands/speckit.extendedflow.quick-review.md` | Self-fixing review agent (review + fix in one pass) |
| Doc check | `commands/speckit.extendedflow.doc-check.md` | Lightweight documentation impact check agent |
| Review template | `templates/review-findings.md` | Structured review output format |
| Doc template | `templates/documentation.md` | Structured doc reconciliation format |
| Resolve spec | `scripts/resolve-spec.py` | Resolves `spec`/`file`/`issue` inputs from the run directory and persists the result |
| Create branch | `scripts/create-branch.py` | Creates feature branch from the run's issue |
| Init quick | `scripts/init-quick.py` | Creates or reuses the Quick Flow feature directory and pointer |
| Verify spec | `scripts/verify-spec.py` | Validates spec file was created |
| Check converge | `scripts/check-converge.py` | Detects whether `speckit.converge` appended new tasks |
| Extract verdict | `scripts/extract-verdict.py` | Extracts the Quick Flow PASS/FAIL from the review filename |
| Resolve bug context | `scripts/resolve-bug-context.py` | Records the standard bug extension's active directory in `feature.json` |
| Check bug verdict | `scripts/check-bug-verdict.py` | Requires a `verified` result in the standard bug test report |
| Load models | `scripts/load-models.py` | Resolves the per-step model config into `load-models.output.data` |

### Downstream Runtime

Downstream workflows invoke the installed runtime scripts with `python3`, so Python 3 must be available on the downstream project's `PATH`. Windows runtime execution has not been verified; this change does not claim Windows support.

Shell steps pass only the engine-validated run id (`{{ context.run_id }}`) on the command line. The scripts read user input from `.specify/workflows/runs/<run_id>/inputs.json` and the resolved instruction from `.specify/workflows/runs/<run_id>/resolved-spec.txt`, so untrusted text is never interpreted by the shell.

## Customization

### Model and integration configuration

Every command step references the `integration` workflow input, which defaults to `"auto"`. Spec-Kit resolves `"auto"` automatically from `.specify/integration.json` (created by `specify init`), so the workflow dispatches to the AI the project was initialized with — no manual configuration needed.

**To override the integration per-run**, pass `--input integration=<key>`:

```bash
specify workflow run spec-kit-extended-flow --input integration=claude
```

#### Per-step models

Each command step binds its `model` from a `load-models` shell step, which reads a JSON config file and exposes it as `load-models.output.data.<step-id>.model`. The config is passed through as-is — a step id that is absent resolves to no model, so the command step uses the agent default. No fixed step list is maintained; keys are simply the step ids in the flow.

The config is a flat object keyed by workflow step id, each value an object with a `model`:

```json
{
  "specify": { "model": "openai/gpt-5" },
  "plan":    { "model": "anthropic/claude-opus-4" },
  "tasks":   { "model": "openai/gpt-5-mini" }
}
```

The keys are the step ids used in the flow (see the workflow YAML for the exact ids, e.g. `specify`, `plan`, `implement`, `finish`). Any step you omit — and any extra key you add — is harmless: only ids a step actually reads have an effect, and everything else uses the agent default.

`load-models.py` resolves the file in this order:

1. The `model_config` input, when set (per-run override).
2. `./model.config.json` at the project root (permanent override that survives reinstall/update).
3. `model.config.json` shipped inside the installed preset (empty by default).

**To override per-run**, point `model_config` at your file:

```bash
specify workflow run spec-kit-extended-flow --input model_config=./my-models.json
```

**To customize permanently**, create `model.config.json` at your project root with just the steps you want to change. Do not edit the copy under `.specify/presets/` — reinstall overwrites it. A config that is missing entirely, or that omits a step, falls back to the agent default; a config that exists but is invalid JSON, not an object, or holds a non-string `model` fails the `load-models` step with a clear error rather than silently misrouting.

> **Security:** `load-models.py` reads the config path in Python; it is never spliced into a shell command. Values in the config are passed to the agent CLI as data.

> **Note:** Model overrides are passed through to the agent CLI (e.g. `opencode run -m <model>`). Support depends on the integration. The opencode integration forwards `-m` automatically; other integrations may ignore the model field.


### Template overrides and stacking

Override templates and adjust review strictness by copying files to `.specify/templates/overrides/`. See [`preset.yml`](../preset.yml) for the full list of overridable templates.

Stack with other presets using priority ordering:

```bash
specify preset add healthcare-compliance --priority 10
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip --priority 5
```
