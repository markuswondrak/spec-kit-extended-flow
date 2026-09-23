#!/usr/bin/env python3
"""Bump all component manifests, commit the change, and create a release tag."""

import re
import shutil
import subprocess
import sys
from pathlib import Path


SEMVER_PATTERN = re.compile(r"^v?([0-9]+)\.([0-9]+)\.([0-9]+)$")
VERSION_PATTERN = re.compile(r'^(  version: )"[^"]+"', re.MULTILINE)
WORKFLOW_FILES = (
    "workflows/workflow.yml",
    "workflows/bugfix-workflow.yml",
    "workflows/quick-flow.yml",
)
BUNDLE_WORKFLOW_IDS = (
    '    - id: "spec-kit-extended-flow"\n',
    '    - id: "spec-kit-bugfix-flow"\n',
    '    - id: "spec-kit-quick-flow"\n',
)
MANIFEST_FILES = ("preset.yml", "extension.yml", "bundle.yml")


def error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def git_output(project_dir: Path, *arguments: str) -> tuple[int, str]:
    result = subprocess.run(
        ["git", "-C", str(project_dir), *arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return result.returncode, result.stdout


def run_git(project_dir: Path, *arguments: str) -> None:
    subprocess.run(["git", "-C", str(project_dir), *arguments], check=True)


def project_directory() -> Path:
    root = Path(__file__).resolve().parent.parent
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    if result.returncode != 0 or Path(result.stdout.strip()).resolve() != root:
        error("The release script must be located in a git repository root.")
    return root


def version_from_manifest(path: Path) -> str:
    match = VERSION_PATTERN.search(path.read_text(encoding="utf-8"))
    return "" if match is None else match.group(0).split('"', 1)[1].rsplit('"', 1)[0]


def update_manifest_version(path: Path, version: str) -> None:
    contents = path.read_text(encoding="utf-8")
    updated_contents, count = VERSION_PATTERN.subn(rf'\1"{version}"', contents, count=1)
    if count:
        path.write_text(updated_contents, encoding="utf-8")


def update_bundle_component_versions(path: Path, version: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    section = ""
    updates = 0
    for index, line in enumerate(lines):
        if line in ("  extensions:\n", "  presets:\n", "  workflows:\n"):
            section = line.strip().rstrip(":")
            continue
        if section == "extensions" and line == '    - id: "extendedflow"\n':
            lines[index + 1] = f'      version: "{version}"\n'
            updates += 1
        if section == "presets" and line == '    - id: "spec-kit-extended-flow"\n':
            lines[index + 1] = f'      version: "{version}"\n'
            updates += 1
        if section == "workflows" and line in BUNDLE_WORKFLOW_IDS:
            lines[index + 1] = f'      version: "{version}"\n'
            updates += 1
    if updates != 5:
        error("Failed to update preset, extension, and workflow versions in bundle.yml")
    path.write_text("".join(lines), encoding="utf-8")


def main(arguments: list[str]) -> int:
    if len(arguments) != 1:
        error("Usage: release-version.py <version>")

    version_match = SEMVER_PATTERN.fullmatch(arguments[0])
    if version_match is None:
        error(
            f"Invalid version format: '{arguments[0]}'. Expected semver: "
            "MAJOR.MINOR.PATCH (e.g., 1.2.3 or v1.2.3)"
        )
    version = ".".join(version_match.groups())

    if shutil.which("git") is None:
        error("Not a git repository. Run from inside a git repository.")
    project_dir = project_directory()

    preset_file = project_dir / "preset.yml"
    extension_file = project_dir / "extension.yml"
    bundle_file = project_dir / "bundle.yml"
    workflow_files = tuple(project_dir / name for name in WORKFLOW_FILES)

    _, status = git_output(project_dir, "status", "--porcelain")
    if status:
        error("Working tree is not clean. Commit or stash changes before releasing.")

    for manifest in (preset_file, extension_file, bundle_file, *workflow_files):
        if not manifest.is_file():
            error(f"Required release file not found at {manifest}")

    current_version = version_from_manifest(preset_file)
    if not current_version:
        error("Could not extract current version from preset.yml")
    if current_version == version:
        error(f"Version is already {version}. Nothing to release.")

    tag = f"v{version}"
    tag_status, _ = git_output(project_dir, "rev-parse", tag)
    if tag_status == 0:
        error(f"Tag already exists: {tag}")

    for manifest in (preset_file, extension_file, bundle_file, *workflow_files):
        update_manifest_version(manifest, version)
    update_bundle_component_versions(bundle_file, version)

    try:
        subprocess.run(
            [sys.executable, str(project_dir / "scripts" / "build-catalog.py")],
            cwd=project_dir,
            check=True,
        )
    except subprocess.CalledProcessError:
        error("Failed to build catalog artifacts and synchronize catalog pins.")

    for manifest in (preset_file, extension_file, bundle_file, *workflow_files):
        if version_from_manifest(manifest) != version:
            error(f"Failed to update version in {manifest.name}")

    run_git(project_dir, "add", *MANIFEST_FILES, *WORKFLOW_FILES, "catalog")
    run_git(project_dir, "commit", "-m", f"chore(release): bump version to {version}")
    run_git(project_dir, "tag", "-a", tag, "-m", f"Release {tag}")

    _, commit = git_output(project_dir, "rev-parse", "--short", "HEAD")
    print(f"Released version {version}")
    print(f"  Commit: {commit.strip()}")
    print(f"  Tag:    {tag}")
    print("\nNext steps:")
    print("  git push origin main --tags")
    print("  Then cut the release from CI:")
    print(f"  gh workflow run release-preset.yml -f version={version}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except subprocess.CalledProcessError as failure:
        raise SystemExit(failure.returncode)
