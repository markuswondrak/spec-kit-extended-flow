# Reference

## Architecture

Extended Flow is delivered as **three artifacts bundled together** — a preset (templates + scripts), an extension (commands), and three workflows — following the Spec-Kit separation of concerns:

| Package | Manifest | Delivers | Installed via |
|---------|----------|----------|---------------|
| **Bundle** | `bundle.yml` | Preset + Extension + Workflows (meta-manifest) | `specify bundle install` |
| Preset | `preset.yml` | Templates, scripts | `specify preset add` |
| Extension | `extension.yml` | Commands (agent prompts) | `specify extension add` |
| Workflow | `workflows/*.yml` | Step orchestration | `specify workflow add` |

This split exists because Spec-Kit's architecture reserves commands for extensions. Presets provide output formats; extensions provide agent behaviors. The bundle acts as a **facade** that composes all three into a single install operation while preserving the ability to install them individually for granular control.

### Key Design Principles

- **Deterministic safety.** Verdict extraction, input validation, conflict flagging, and format checks produce reproducible outcomes. When the pipeline passes, fails, or flags a conflict, you can understand why without reading source code.
- **Human gates as fallback, not requirement.** Every guard rail is deterministic and inspectable. Human gates are available but not required for correct results.
- **Never auto-resolve code-vs-docs conflicts.** The documentation reconciler flags contradictions for human resolution. This is a core invariant.
- **Single-responsibility inputs.** Each input parameter (`spec`, `file`, `issue`) has exactly one resolution strategy. No regex-based format detection, no guessing.

### Component Map

| Component | File | Role |
|-----------|------|------|
| Review agent | `commands/speckit.extendedflow.review.md` | QA agent system prompt |
| Fix agent | `commands/speckit.extendedflow.fix.md` | Targeted fix agent system prompt |
| Documentation agent | `commands/speckit.extendedflow.documentation.md` | Doc reconciliation agent prompt |
| Documentation init | `commands/speckit.extendedflow.documentation-init.md` | Doc bootstrap agent prompt |
| Project init | `commands/speckit.extendedflow.project-init.md` | Project analysis + template tailoring agent prompt |
| Finish agent | `commands/speckit.extendedflow.finish.md` | Cleanup, commit, PR agent prompt |
| Quick implement | `commands/speckit.extendedflow.quick-implement.md` | Direct implementation agent for trivial changes |
| Quick review | `commands/speckit.extendedflow.quick-review.md` | Self-fixing review agent (review + fix in one pass) |
| Doc check | `commands/speckit.extendedflow.doc-check.md` | Lightweight documentation impact check agent |
| Review template | `templates/review-findings.md` | Structured review output format |
| Doc template | `templates/documentation.md` | Structured doc reconciliation format |
| Bug analysis template | `templates/bug-analysis.md` | Structured bug analysis output format |
| Resolve spec | `scripts/resolve-spec.sh` | Resolves spec/file/issue inputs |
| Create branch | `scripts/create-branch.sh` | Creates feature branch from issue |
| Init quick | `scripts/init-quick.sh` | Initializes Quick Flow feature directory |
| Verify spec | `scripts/verify-spec.sh` | Validates spec file was created |
| Extract verdict | `scripts/extract-verdict.sh` | Extracts PASS/FAIL from review filename |

## Customization

### Model and integration configuration

Every command step references the `integration` workflow input, which defaults to `"auto"`. Spec-Kit resolves `"auto"` automatically from `.specify/integration.json` (created by `specify init`), so the workflow dispatches to the AI the project was initialized with — no manual configuration needed. Each step also has a `model` attribute that defaults to `""` (agent default).

**To override per-run**, pass `--input integration=<key>`:

```bash
specify workflow run spec-kit-extended-flow --input integration=claude
```

**To customize permanently**, edit the installed workflow directly. Open `.specify/workflows/<id>/workflow.yml` and replace `{{ inputs.integration }}` with a literal integration key on the steps you want to configure:

```yaml
  - id: plan
    command: speckit.plan
    integration: "opencode"
    model: "glm"
    # ...

  - id: implement
    command: speckit.implement
    integration: "opencode"
    model: "kimi"
    # ...
```

This lets you pair agents and models to their strengths — for example, a reasoning-focused model for planning and a coding-focused model for implementation — without passing inputs on every run.

> **Note:** Model overrides are passed through to the agent CLI (e.g. `opencode run -m <model>`). Support depends on the integration. The opencode integration forwards `-m` automatically; other integrations may ignore the model field.

### Template overrides and stacking

Override templates and adjust review strictness by copying files to `.specify/templates/overrides/`. See [`preset.yml`](../preset.yml) for the full list of overridable templates.

Stack with other presets using priority ordering:

```bash
specify preset add healthcare-compliance --priority 10
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip --priority 5
```
