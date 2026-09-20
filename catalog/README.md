# Project-owned Spec Kit catalog

A catalog owned by this repository, served over HTTPS from `raw.githubusercontent.com`.
It lets `specify bundle install` resolve this repository's own components without a
local HTTP server or `--dev` symlinks.

The catalogs are integration-agnostic and install-allowed: they are the sanctioned
mechanism for repository-local components (see
[spec-kit#3058](https://github.com/github/spec-kit/issues/3058)).

## Contents

| File | Purpose |
|---|---|
| `extension-catalog.json` | Points at the `extendedflow` extension archive. |
| `preset-catalog.json` | Points at the `spec-kit-extended-flow` preset archive. |
| `workflow-catalog.json` | Points directly at the four `workflows/*.yml` definitions. |
| `bundle-catalog.json` | Points at the built bundle artifact. |
| `artifacts/` | Generated archives referenced by the catalogs. |

## Build

Regenerate `artifacts/` and sync the catalog version pins after changing a component:

```bash
python3 scripts/build-catalog.py
```

The archives are build outputs and are **not committed** (see `.gitignore`). They are
published as GitHub release assets on `v<version>`; the catalog `download_url` fields
point at those release assets, so the catalogs in `main` stay resolvable without
carrying binaries in git.

## Register

Catalogs are registered per project. The manual equivalent is:

```bash
BASE=https://raw.githubusercontent.com/markuswondrak/spec-kit-extended-flow/main
specify extension catalog add "$BASE/catalog/extension-catalog.json" --name spec-kit-extended-flow --install-allowed --priority 1
specify preset catalog add "$BASE/catalog/preset-catalog.json" --name spec-kit-extended-flow --install-allowed --priority 1
specify workflow catalog add "$BASE/catalog/workflow-catalog.json" --name spec-kit-extended-flow
specify bundle catalog add "$BASE/catalog/bundle-catalog.json" --id spec-kit-extended-flow --priority 1
```

Then install:

```bash
specify bundle install spec-kit-extended-flow
```
