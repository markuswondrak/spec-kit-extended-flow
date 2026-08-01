# Releasing

To cut a new release:

```bash
scripts/release-version.sh 1.2.3
git push origin main --tags
```

This validates the version format (semver), updates `preset.yml` and `extension.yml`, commits the bump, creates an annotated tag, and triggers the GitHub Actions release workflow.
