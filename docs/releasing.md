# Releasing

To cut a new release:

```bash
python3 scripts/release-version.py 1.2.3
git push origin main --tags
```

This validates the version format (semver), updates `preset.yml`, `extension.yml`, and `bundle.yml` (including its component pins), commits the bump, creates an annotated tag, and triggers the GitHub Actions release workflow. Release publishing runs on Linux; downstream flow runtime requires only Python 3 plus the optional `git` and `gh` integrations it uses.
