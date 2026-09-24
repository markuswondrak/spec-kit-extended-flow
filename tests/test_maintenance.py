"""Isolated black-box tests for deterministic package and catalog builds."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PYTHON = sys.executable
RUNTIME_SCRIPTS = {
    "resolve-spec.py",
    "create-branch.py",
    "check-converge.py",
    "extract-verdict.py",
    "resolve-bug-context.py",
    "check-bug-verdict.py",
    "verify-spec.py",
    "init-quick.py",
    "resolve-pr-template.py",
    "load-models.py",
}


class MaintenanceScriptTests(unittest.TestCase):
    def copy_project(self, destination):
        shutil.copytree(
            ROOT,
            destination,
            ignore=shutil.ignore_patterns(".git", "__pycache__", "dist", "artifacts"),
        )

    def run_script(self, project, script, *args, env=None):
        environment = os.environ.copy()
        if env:
            environment.update(env)
        return subprocess.run(
            [PYTHON, str(project / "scripts" / script), *args],
            cwd=project,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def archive_metadata(self, archive):
        with zipfile.ZipFile(archive) as output:
            self.assertIsNone(output.testzip())
            return {
                entry.filename: (entry.date_time, stat.S_IMODE(entry.external_attr >> 16), entry.is_dir())
                for entry in output.infolist()
            }

    def test_package_preset_is_reproducible_and_contains_only_runtime_assets(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "project"
            self.copy_project(project)
            dist = project / "output"
            first = self.run_script(project, "package-preset.py", env={"DIST_DIR": str(dist)})
            archive = Path(first.stdout.strip())
            first_bytes = archive.read_bytes()
            second = self.run_script(project, "package-preset.py", env={"DIST_DIR": str(dist)})
            second_bytes = archive.read_bytes()
            contents = self.archive_metadata(archive)

        self.assertEqual((first.returncode, first.stderr), (0, ""))
        self.assertEqual((second.returncode, second.stderr), (0, ""))
        self.assertEqual(first_bytes, second_bytes)
        self.assertEqual(set(contents) & {"tests/", "scripts/package-preset.py"}, set())
        self.assertTrue(RUNTIME_SCRIPTS <= set(path.removeprefix("scripts/") for path in contents if path.startswith("scripts/")))
        self.assertFalse(any(name.endswith(".sh") for name in contents))
        self.assertIn("model.config.json", contents)
        for script in RUNTIME_SCRIPTS:
            self.assertTrue((ROOT / "scripts" / script).stat().st_mode & stat.S_IXUSR)
            timestamp, mode, is_directory = contents[f"scripts/{script}"]
            self.assertEqual(timestamp, (1980, 1, 1, 0, 0, 0))
            self.assertFalse(is_directory)
            self.assertTrue(mode & stat.S_IXUSR)

    def test_catalog_build_is_reproducible_and_synchronizes_isolated_catalogs(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "project"
            self.copy_project(project)
            first = self.run_script(project, "build-catalog.py")
            artifacts = sorted((project / "catalog/artifacts").glob("*.zip"))
            first_digests = {artifact.name: hashlib.sha256(artifact.read_bytes()).hexdigest() for artifact in artifacts}
            second = self.run_script(project, "build-catalog.py")
            second_digests = {artifact.name: hashlib.sha256(artifact.read_bytes()).hexdigest() for artifact in artifacts}
            extension_catalog = json.loads((project / "catalog/extension-catalog.json").read_text(encoding="utf-8"))
            preset_catalog = json.loads((project / "catalog/preset-catalog.json").read_text(encoding="utf-8"))
            bundle_catalog = json.loads((project / "catalog/bundle-catalog.json").read_text(encoding="utf-8"))
            archive_contents = {artifact.name: self.archive_metadata(artifact) for artifact in artifacts}

        self.assertEqual((first.returncode, first.stderr), (0, ""))
        self.assertEqual((second.returncode, second.stderr), (0, ""))
        self.assertEqual(first_digests, second_digests)
        self.assertEqual(len(artifacts), 4)
        self.assertIn("extension.yml", archive_contents[next(name for name in archive_contents if name.startswith("extendedflow-"))])
        preset_archive = next(name for name in archive_contents if name.startswith("spec-kit-extended-flow-") and "bundle" not in name)
        self.assertTrue({f"scripts/{script}" for script in RUNTIME_SCRIPTS} <= set(archive_contents[preset_archive]))
        self.assertIn("model.config.json", archive_contents[preset_archive])
        self.assertNotIn("scripts/build-catalog.py", archive_contents[preset_archive])
        delegation_archive = next(name for name in archive_contents if name.startswith("sub-agent-delegation-"))
        self.assertIn("preset.yml", archive_contents[delegation_archive])
        self.assertIn("commands/sub-agent-delegation.md", archive_contents[delegation_archive])
        for catalog, section, identifier in (
            (extension_catalog, "extensions", "extendedflow"),
            (preset_catalog, "presets", "spec-kit-extended-flow"),
            (preset_catalog, "presets", "sub-agent-delegation"),
            (bundle_catalog, "bundles", "spec-kit-extended-flow"),
        ):
            entry = catalog[section][identifier]
            self.assertIn(f"v{entry['version']}/", entry["download_url"])
            self.assertTrue(entry["download_url"].endswith(".zip"))

    def test_release_version_synchronizes_bundle_component_pins(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "project"
            self.copy_project(project)
            subprocess.run(["git", "init", "-b", "main", str(project)], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["git", "-C", str(project), "config", "user.email", "tests@example.com"], check=True)
            subprocess.run(["git", "-C", str(project), "config", "user.name", "Tests"], check=True)
            subprocess.run(["git", "-C", str(project), "add", "."], check=True)
            subprocess.run(["git", "-C", str(project), "commit", "-m", "initial"], check=True, stdout=subprocess.DEVNULL)
            result = self.run_script(project, "release-version.py", "1.2.3")
            checked = self.run_script(project, "check-release.py", "1.2.3")
            mismatched = self.run_script(project, "check-release.py", "9.9.9")
            manifests = {
                name: (project / name).read_text(encoding="utf-8")
                for name in ("preset.yml", "extension.yml", "bundle.yml")
            }
            delegation_manifest = (
                project / "presets" / "sub-agent-delegation" / "preset.yml"
            ).read_text(encoding="utf-8")
            workflows = {
                name: (project / "workflows" / name).read_text(encoding="utf-8")
                for name in ("workflow.yml", "bugfix-workflow.yml", "quick-flow.yml")
            }
            catalogs = {
                name: json.loads((project / "catalog" / name).read_text(encoding="utf-8"))
                for name in (
                    "extension-catalog.json",
                    "preset-catalog.json",
                    "bundle-catalog.json",
                    "workflow-catalog.json",
                )
            }
            tags = subprocess.run(
                ["git", "-C", str(project), "tag", "-l", "v1.2.3"],
                check=True,
                text=True,
                stdout=subprocess.PIPE,
            )

        self.assertEqual((result.returncode, result.stderr), (0, ""))
        self.assertIn("Released version 1.2.3", result.stdout)
        self.assertIn('version: "1.2.3"', manifests["preset.yml"])
        self.assertIn('version: "1.2.3"', manifests["extension.yml"])
        self.assertIn('version: "1.2.3"', delegation_manifest)
        self.assertEqual(manifests["bundle.yml"].count('version: "1.2.3"'), 7)
        self.assertIn('version: "1.0.0"', manifests["bundle.yml"])
        for name, contents in workflows.items():
            self.assertIn('version: "1.2.3"', contents)
        self.assertEqual(catalogs["extension-catalog.json"]["extensions"]["extendedflow"]["version"], "1.2.3")
        self.assertEqual(catalogs["preset-catalog.json"]["presets"]["spec-kit-extended-flow"]["version"], "1.2.3")
        self.assertEqual(catalogs["preset-catalog.json"]["presets"]["sub-agent-delegation"]["version"], "1.2.3")
        self.assertEqual(catalogs["bundle-catalog.json"]["bundles"]["spec-kit-extended-flow"]["version"], "1.2.3")
        for workflow_id in ("spec-kit-extended-flow", "spec-kit-bugfix-flow", "spec-kit-quick-flow"):
            self.assertEqual(catalogs["workflow-catalog.json"]["workflows"][workflow_id]["version"], "1.2.3")
        self.assertEqual(checked.returncode, 0)
        self.assertEqual(mismatched.returncode, 1)
        self.assertEqual(tags.stdout, "v1.2.3\n")

    def test_release_version_uses_the_script_repository_not_the_callers_repository(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            project = root / "project"
            caller = root / "caller"
            self.copy_project(project)
            for repository in (project, caller):
                subprocess.run(["git", "init", "-b", "main", str(repository)], check=True, stdout=subprocess.DEVNULL)
                subprocess.run(["git", "-C", str(repository), "config", "user.email", "tests@example.com"], check=True)
                subprocess.run(["git", "-C", str(repository), "config", "user.name", "Tests"], check=True)
                (repository / "marker.txt").write_text("initial\n", encoding="utf-8")
                subprocess.run(["git", "-C", str(repository), "add", "."], check=True)
                subprocess.run(["git", "-C", str(repository), "commit", "-m", "initial"], check=True, stdout=subprocess.DEVNULL)

            caller_head = subprocess.run(
                ["git", "-C", str(caller), "rev-parse", "HEAD"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            result = subprocess.run(
                [PYTHON, str(project / "scripts" / "release-version.py"), "1.2.3"],
                cwd=caller,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            caller_after = subprocess.run(
                ["git", "-C", str(caller), "rev-parse", "HEAD"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            caller_tags = subprocess.run(
                ["git", "-C", str(caller), "tag", "--list"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            project_tags = subprocess.run(
                ["git", "-C", str(project), "tag", "--list", "v1.2.3"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout

        self.assertEqual((result.returncode, result.stderr), (0, ""))
        self.assertEqual(caller_after, caller_head)
        self.assertEqual(caller_tags, "")
        self.assertEqual(project_tags, "v1.2.3\n")

    def test_release_uses_the_script_repository_not_the_callers_repository(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            project = root / "project"
            caller = root / "caller"
            self.copy_project(project)
            for repository in (project, caller):
                subprocess.run(["git", "init", "-b", "main", str(repository)], check=True, stdout=subprocess.DEVNULL)
                subprocess.run(["git", "-C", str(repository), "config", "user.email", "tests@example.com"], check=True)
                subprocess.run(["git", "-C", str(repository), "config", "user.name", "Tests"], check=True)
                (repository / "marker.txt").write_text("initial\n", encoding="utf-8")
                subprocess.run(["git", "-C", str(repository), "add", "."], check=True)
                subprocess.run(["git", "-C", str(repository), "commit", "-m", "initial"], check=True, stdout=subprocess.DEVNULL)

            caller_head = subprocess.run(
                ["git", "-C", str(caller), "rev-parse", "HEAD"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            current_version = next(
                line.split('"')[1]
                for line in (project / "preset.yml").read_text(encoding="utf-8").splitlines()
                if line.startswith("  version: ")
            )
            major, minor, _ = (int(part) for part in current_version.split("."))
            expected_tag = f"v{major}.{minor + 1}.0"
            result = subprocess.run(
                [PYTHON, str(project / "scripts" / "release.py")],
                cwd=caller,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            caller_after = subprocess.run(
                ["git", "-C", str(caller), "rev-parse", "HEAD"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            caller_tags = subprocess.run(
                ["git", "-C", str(caller), "tag", "--list"], check=True, text=True, stdout=subprocess.PIPE
            ).stdout
            project_tags = subprocess.run(
                ["git", "-C", str(project), "tag", "--list", expected_tag], check=True, text=True, stdout=subprocess.PIPE
            ).stdout

        self.assertEqual((result.returncode, result.stderr), (0, ""))
        self.assertEqual(caller_after, caller_head)
        self.assertEqual(caller_tags, "")
        self.assertEqual(project_tags, f"{expected_tag}\n")

    def init_repository(self, project):
        subprocess.run(["git", "init", "-b", "main", str(project)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run(["git", "-C", str(project), "config", "user.email", "tests@example.com"], check=True)
        subprocess.run(["git", "-C", str(project), "config", "user.name", "Tests"], check=True)
        subprocess.run(["git", "-C", str(project), "add", "."], check=True)
        subprocess.run(
            ["git", "-C", str(project), "commit", "-m", "initial"],
            check=True,
            stdout=subprocess.DEVNULL,
        )

    def test_check_release_detects_manifest_workflow_and_pin_drift(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "project"
            self.copy_project(project)
            self.init_repository(project)
            self.run_script(project, "release-version.py", "1.2.3")

            consistent = self.run_script(project, "check-release.py", "1.2.3")

            workflow_file = project / "workflows" / "quick-flow.yml"
            workflow_file.write_text(
                workflow_file.read_text(encoding="utf-8").replace(
                    'version: "1.2.3"', 'version: "9.9.9"', 1
                ),
                encoding="utf-8",
            )
            workflow_drift = self.run_script(project, "check-release.py", "1.2.3")

            bundle_file = project / "bundle.yml"
            bundle_file.write_text(
                bundle_file.read_text(encoding="utf-8").replace(
                    'id: "spec-kit-bugfix-flow"\n      version: "1.2.3"',
                    'id: "spec-kit-bugfix-flow"\n      version: "9.9.9"',
                    1,
                ),
                encoding="utf-8",
            )
            pin_drift = self.run_script(project, "check-release.py", "1.2.3")

        self.assertEqual((consistent.returncode, consistent.stderr), (0, ""))
        self.assertEqual(workflow_drift.returncode, 1)
        self.assertIn("quick-flow.yml", workflow_drift.stderr)
        self.assertEqual(pin_drift.returncode, 1)
        self.assertIn("spec-kit-bugfix-flow", pin_drift.stderr)

    def test_check_release_verifies_release_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            project = Path(temporary_directory) / "project"
            self.copy_project(project)
            self.init_repository(project)
            self.run_script(project, "release-version.py", "1.2.3")
            self.run_script(project, "package-preset.py")
            self.run_script(project, "build-catalog.py")

            verified = self.run_script(project, "check-release.py", "1.2.3", "--artifacts")

            (project / "catalog" / "artifacts" / "extendedflow-1.2.3.zip").unlink()
            missing = self.run_script(project, "check-release.py", "1.2.3", "--artifacts")

        self.assertEqual((verified.returncode, verified.stderr), (0, ""))
        self.assertEqual(missing.returncode, 1)
        self.assertIn("extendedflow-1.2.3.zip", missing.stderr)

    def test_release_workflow_is_manual_only_and_gated(self):
        workflow = (ROOT / ".github/workflows/release-preset.yml").read_text(encoding="utf-8")
        self.assertIn("workflow_dispatch:", workflow)
        self.assertNotIn("push:", workflow)
        self.assertIn("python -m unittest discover", workflow)
        self.assertIn("scripts/check-release.py", workflow)
        self.assertIn("--generate-notes", workflow)
        self.assertIn("--clobber", workflow)
