"""Target-state static contracts for Python runtime migration."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
PRESET_PATH = ".specify/presets/spec-kit-extended-flow/scripts"
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


class PythonRuntimeStaticContracts(unittest.TestCase):
    def test_all_packaged_runtime_scripts_are_python_files(self):
        for script in RUNTIME_SCRIPTS:
            path = ROOT / "scripts" / script
            with self.subTest(script=script):
                self.assertTrue(path.is_file())
                self.assertTrue(path.read_text(encoding="utf-8").startswith("#!/usr/bin/env python3\n"))

    def test_workflows_invoke_python_runtime_scripts_and_preserve_resolve_stdout_contract(self):
        expected = {
            "workflow.yml": ("resolve-spec.py", "create-branch.py", "verify-spec.py", "check-converge.py"),
            "bugfix-workflow.yml": ("resolve-spec.py", "create-branch.py", "resolve-bug-context.py", "check-bug-verdict.py"),
            "quick-flow.yml": ("resolve-spec.py", "create-branch.py", "init-quick.py", "extract-verdict.py"),
        }
        for workflow, scripts in expected.items():
            with self.subTest(workflow=workflow):
                content = (ROOT / "workflows" / workflow).read_text(encoding="utf-8")
                self.assertIn("steps.resolve-spec.output.stdout", content)
                self.assertNotIn(".sh", content)
                for script in scripts:
                    self.assertIn(f"python3 {PRESET_PATH}/{script}", content)

    def test_documentation_describes_python_runtime_scripts_not_shell_scripts(self):
        documentation = "".join(
            path.read_text(encoding="utf-8")
            for path in (
                ROOT / "AGENTS.md",
                ROOT / "README.md",
                ROOT / "docs/reference.md",
                ROOT / "docs/troubleshooting.md",
                ROOT / "docs/releasing.md",
                ROOT / "catalog/README.md",
            )
        )
        self.assertNotIn("scripts/resolve-spec.sh", documentation)
        for script in RUNTIME_SCRIPTS:
            self.assertNotIn(f"scripts/{script.removesuffix('.py')}.sh", documentation)
        for script in RUNTIME_SCRIPTS:
            with self.subTest(script=script):
                self.assertIn(f"scripts/{script}", documentation)

    def test_no_shipped_shell_runtime_or_bash_call_sites_remain(self):
        self.assertEqual(list((ROOT / "scripts").glob("*.sh")), [])
        call_sites = "".join(
            path.read_text(encoding="utf-8")
            for path in (
                ROOT / "workflows/workflow.yml",
                ROOT / "workflows/bugfix-workflow.yml",
                ROOT / "workflows/quick-flow.yml",
                ROOT / "commands/speckit.extendedflow.finish.md",
            )
        )
        self.assertNotIn("bash .specify/presets/spec-kit-extended-flow/scripts/", call_sites)
