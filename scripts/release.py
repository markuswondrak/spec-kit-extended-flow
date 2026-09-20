#!/usr/bin/env python3
"""Merge a release branch, bump the minor version, tag it, and push it."""

import re
import shutil
import subprocess
import sys
from pathlib import Path


SEMVER_PATTERN = re.compile(r"^([0-9]+)\.([0-9]+)\.([0-9]+)$")
VERSION_PATTERN = re.compile(r'^(  version: )"[^"]+"', re.MULTILINE)


def error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def info(message: str) -> None:
    print(f"INFO: {message}")


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
    if updates != 2:
        error("Failed to update preset and extension versions in bundle.yml")
    path.write_text("".join(lines), encoding="utf-8")


def main() -> int:
    if shutil.which("git") is None:
        error("Not a git repository. Run from inside a git repository.")
    project_dir = project_directory()

    preset_file = project_dir / "preset.yml"
    extension_file = project_dir / "extension.yml"
    bundle_file = project_dir / "bundle.yml"
    for manifest, name in (
        (preset_file, "preset.yml"),
        (extension_file, "extension.yml"),
        (bundle_file, "bundle.yml"),
    ):
        if not manifest.is_file():
            error(f"{name} not found at {manifest}")

    _, current_branch = git_output(project_dir, "branch", "--show-current")
    current_branch = current_branch.strip()
    if not current_branch:
        error("Could not determine current branch. Ensure you are on a branch (not detached HEAD).")
    info(f"Current branch: {current_branch}")

    _, status = git_output(project_dir, "status", "--porcelain")
    if status:
        info("Uncommitted changes detected. Committing...")
        run_git(project_dir, "add", "-A")
        run_git(project_dir, "commit", "-m", "chore: prepare release")
    else:
        info("Working tree is clean.")

    main_branch = "main"
    main_exists, _ = git_output(project_dir, "show-ref", "--verify", "--quiet", "refs/heads/main")
    if main_exists != 0:
        master_exists, _ = git_output(project_dir, "show-ref", "--verify", "--quiet", "refs/heads/master")
        if master_exists == 0:
            main_branch = "master"
        else:
            run_git(project_dir, "branch", main_branch)

    if current_branch != main_branch:
        info(f"Switching to {main_branch} and merging {current_branch}...")
        run_git(project_dir, "checkout", main_branch)
        run_git(
            project_dir,
            "merge",
            "--no-ff",
            current_branch,
            "-m",
            f"chore(release): merge {current_branch} into {main_branch}",
        )
    else:
        info(f"Already on {main_branch}.")

    current_version = version_from_manifest(preset_file)
    if not current_version:
        error("Could not extract current version from preset.yml")
    info(f"Current version: {current_version}")

    version_match = SEMVER_PATTERN.fullmatch(current_version)
    if version_match is None:
        error(
            f"Invalid version format in preset.yml: '{current_version}'. "
            "Expected semver: MAJOR.MINOR.PATCH"
        )
    major, minor, _ = version_match.groups()
    version = f"{major}.{int(minor) + 1}.0"
    info(f"Next version: {version}")

    tag = f"v{version}"
    tag_status, _ = git_output(project_dir, "rev-parse", tag)
    if tag_status == 0:
        error(f"Tag already exists: {tag}")

    for manifest in (preset_file, extension_file, bundle_file):
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

    if version_from_manifest(preset_file) != version:
        error("Failed to update version in preset.yml")
    if version_from_manifest(extension_file) != version:
        error("Failed to update version in extension.yml")
    if version_from_manifest(bundle_file) != version:
        error("Failed to update version in bundle.yml")

    run_git(project_dir, "add", str(preset_file), str(extension_file), str(bundle_file), "catalog")
    run_git(project_dir, "commit", "-m", f"chore(release): bump version to {version}")
    run_git(project_dir, "tag", "-a", tag, "-m", f"Release {tag}")

    info(f"Pushing {main_branch} and tags to origin...")
    remote_status, _ = git_output(project_dir, "remote", "get-url", "origin")
    if remote_status == 0:
        run_git(project_dir, "push", "origin", main_branch, "--tags")
    else:
        info("No remote 'origin' configured. Skipping push.")
        info(f"To push manually, run: git push origin {main_branch} --tags")

    _, commit = git_output(project_dir, "rev-parse", "--short", "HEAD")
    print("\n========================================")
    print(f"  Released version {version}")
    print(f"  Commit: {commit.strip()}")
    print(f"  Tag:    {tag}")
    print(f"  Branch: {main_branch}")
    print("========================================")
    print("\nPublishing runs from CI. Cut the release with:")
    print(f"  gh workflow run release-preset.yml -f version={version}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as failure:
        raise SystemExit(failure.returncode)
