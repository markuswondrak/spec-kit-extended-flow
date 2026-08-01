# Troubleshooting

## Git Extension Compatibility

Extended Flow manages its own branch creation (issue-based naming: `feature/<issue>-<slug>`) and conflicts with spec-kit's built-in git extension, which uses sequential numbering (`001-<slug>`) via a `before_specify` hook.

`speckit.extendedflow.project-init` runs `specify extension disable git` automatically during setup and reports the outcome. You do not need to do this manually.

**Why this is necessary:**
- The git extension registers a mandatory `before_specify` hook (`speckit.git.feature`) that creates branches with sequential numbering
- Our workflows create branches with issue-based naming via `create-branch.sh`
- On integrations that do not support the `EXECUTE_COMMAND` protocol (e.g., opencode), the mandatory hook causes the agent to hang waiting for a result that never comes
- Disabling the git extension eliminates the conflict and allows the workflows to manage branching consistently

**What you lose:**
- Auto-commits after each SDD step (optional and disabled by default anyway)
- `speckit.git.feature` command (our workflows handle branch creation instead)

**What you keep:**
- All core spec-kit commands (`speckit.specify`, `speckit.plan`, `speckit.tasks`, `speckit.implement`)
- All extended flow commands (`speckit.extendedflow.review`, `speckit.extendedflow.fix`, etc.)
- Issue-to-PR automation via the `finish` command

To re-enable the git extension later (if you stop using Extended Flow):
```bash
specify extension enable git
```

## Common Issues

**Reviewer always returns FAIL:** Check that `.specify/spec.md` is up to date. Review findings are inside the current feature directory (`specs/<NNN>-<feature>/review-findings.md`). Adjust `max_iterations` in `workflows/workflow.yml` if needed.

**Workflow stuck in loop:** Check `specify workflow status`. The cap of 5 iterations prevents infinite loops.

**Workflow not found by ID:** Install it: `specify workflow add .specify/presets/spec-kit-extended-flow/workflows/workflow.yml`

**GitHub issue not resolving:** Ensure `gh` CLI is installed and authenticated (`gh auth status`). The `issue` parameter only supports issues from the current repository (bare number, e.g., `42`). Cross-repo references and full URLs are not supported.

**Commands not appearing:** Ensure both the preset and extension are installed:
```bash
specify preset add --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
specify extension add extendedflow --from https://github.com/markuswondrak/spec-kit-extended-flow/releases/latest/download/spec-kit-extended-flow.zip
```

**No spec created after specify step (specs/ is empty):** This happens when the git extension's `before_specify` hook tries to execute via `EXECUTE_COMMAND`, but the integration does not support it (e.g., opencode). The workflow includes a `verify-spec` safety net that catches this and aborts with a clear error. To fix: run `/speckit.extendedflow.project-init` (which disables the git extension), or manually run `specify extension disable git`. See [Git Extension Compatibility](#git-extension-compatibility) above.

## Installation Notes

`specify preset add --from` expects a ZIP package URL. The same applies to `specify extension add --from`. Do not pass the GitHub repository landing page URL — that downloads HTML, not a preset package.

Release packages are built as `dist/spec-kit-extended-flow.zip` by `scripts/package-preset.sh` and published as GitHub Release assets by `.github/workflows/release-preset.yml`.
