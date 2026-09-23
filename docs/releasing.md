# Releasing

Releases are cut from CI. The `Release bundle` workflow
(`.github/workflows/release-preset.yml`) is triggered manually and releases the
entire bundle — preset, extension, the three workflows, and the catalogs — under a
single version.

## Cut a release

```bash
gh workflow run release-preset.yml -f version=1.2.3
```

The workflow, in order:

1. Resolves and validates the requested semver (`v1.2.3` and `1.2.3` are equivalent).
2. Bumps **every** component to that version:
   - `preset.yml`, `extension.yml`, `bundle.yml`,
   - `bundle.yml` component pins (`extensions`, `presets`, `workflows`),
   - `workflows/workflow.yml`, `workflows/bugfix-workflow.yml`,
     `workflows/quick-flow.yml`.
3. Regenerates the catalog artifacts and pins via `scripts/build-catalog.py`.
4. Commits the bump and creates the annotated `v<version>` tag on the default branch.
5. Verifies consistency with `scripts/check-release.py` (tag version == every
   manifest, workflow, and catalog pin). The job fails on any mismatch.
6. Runs the full test suite (`python -m unittest discover -s tests -t .`).
7. Builds `dist/spec-kit-extended-flow.zip` and the catalog archives, then verifies
   them (presence and ZIP integrity) with `check-release.py --artifacts`.
8. Publishes or updates the GitHub release, attaching all artifacts with
   `--clobber`. Notes are generated from the git history via `--generate-notes`.

## Re-running a release

The workflow is idempotent. If `v<version>` already exists it checks out that tag
instead of bumping, rebuilds the artifacts, and re-uploads them (`--clobber`). This
also supports tagging locally and then dispatching the release.

## Consistency check

`scripts/check-release.py` is the deterministic gate and is useful on its own:

```bash
python3 scripts/check-release.py 1.2.3             # manifests, workflows, catalogs
python3 scripts/check-release.py 1.2.3 --artifacts # also verify built archives
```

## Local helpers

`scripts/release-version.py <version>` performs steps 2-4 locally when you need the
bump without CI (it leaves pushing and publishing to the workflow above).
`scripts/release.py` merges the current branch, bumps the minor version, tags, and
pushes — useful for preparing a branch for release. Neither publishes; dispatch the
workflow afterward.

Release publishing runs on Linux; downstream flow runtime requires only Python 3 plus
the optional `git` and `gh` integrations it uses.
