#!/usr/bin/env python3
"""Build the distributable Extended Flow preset archive."""

import os
import stat
import sys
import tempfile
import zipfile
from pathlib import Path


RUNTIME_SCRIPTS = (
    "resolve-spec.py",
    "create-branch.py",
    "check-converge.py",
    "extract-verdict.py",
    "resolve-bug-context.py",
    "check-bug-verdict.py",
    "verify-spec.py",
    "init-quick.py",
    "resolve-pr-template.py",
)

REQUIRED_PATHS = (
    "preset.yml",
    "extension.yml",
    "bundle.yml",
    "workflows/workflow.yml",
    "workflows/bugfix-workflow.yml",
    "workflows/quick-flow.yml",
    "commands/speckit.extendedflow.documentation-init.md",
    "commands/speckit.extendedflow.documentation.md",
    "commands/speckit.extendedflow.project-init.md",
    "commands/workflow-runtime.md",
    "templates/documentation.md",
    "templates/review-findings.md",
    *(f"scripts/{script}" for script in RUNTIME_SCRIPTS),
)

ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def error(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def zip_info(name: str, mode: int, is_directory: bool) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
    info.create_system = 3
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (mode & 0xFFFF) << 16
    if is_directory:
        info.external_attr |= 0x10
    return info


def write_archive(archive: Path, entries: dict[str, Path]) -> None:
    directories = set()
    for name in entries:
        parent = Path(name).parent
        while parent != Path("."):
            directories.add(f"{parent.as_posix()}/")
            parent = parent.parent

    archive_entries: dict[str, Path | None] = {directory: None for directory in directories}
    archive_entries.update(entries)

    with zipfile.ZipFile(
        archive,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        strict_timestamps=True,
    ) as output:
        for name in sorted(archive_entries):
            source = archive_entries[name]
            if source is None:
                output.writestr(zip_info(name, 0o40755, True), b"")
                continue
            mode = stat.S_IMODE(source.stat().st_mode)
            output.writestr(zip_info(name, stat.S_IFREG | mode, False), source.read_bytes())

    with zipfile.ZipFile(archive) as output:
        invalid_entry = output.testzip()
    if invalid_entry is not None:
        error("Generated ZIP failed integrity check.")


def main() -> int:
    project_dir = Path(__file__).resolve().parent.parent
    dist_dir = Path(os.environ.get("DIST_DIR", str(project_dir / "dist")))
    package_name = os.environ.get("PACKAGE_NAME", "spec-kit-extended-flow.zip")
    package_path = dist_dir / package_name

    for relative_path in REQUIRED_PATHS:
        if not (project_dir / relative_path).exists():
            error(f"Required package path missing: {relative_path}")

    entries = {
        name: project_dir / name
        for name in (
            "preset.yml",
            "extension.yml",
            "bundle.yml",
            "workflows/workflow.yml",
            "workflows/bugfix-workflow.yml",
            "workflows/quick-flow.yml",
            "README.md",
        )
    }
    for source in sorted((project_dir / "commands").glob("*.md")):
        entries[f"commands/{source.name}"] = source
    for source in sorted((project_dir / "templates").glob("*.md")):
        entries[f"templates/{source.name}"] = source
    for script in RUNTIME_SCRIPTS:
        entries[f"scripts/{script}"] = project_dir / "scripts" / script
    for license_name in ("LICENSE", "LICENSE.md"):
        source = project_dir / license_name
        if source.is_file():
            entries[license_name] = source

    dist_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dist_dir) as temporary_directory:
        temporary_path = Path(temporary_directory) / package_name
        write_archive(temporary_path, entries)
        os.replace(temporary_path, package_path)

    print(package_path)
    return 0


if __name__ == "__main__":
    main()
