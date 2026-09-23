"""Target-state static contracts for Python runtime migration."""

from pathlib import Path
import re
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
    "load-models.py",
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
            "workflow.yml": ("resolve-spec.py", "create-branch.py", "verify-spec.py", "check-converge.py", "load-models.py"),
            "bugfix-workflow.yml": ("resolve-spec.py", "create-branch.py", "resolve-bug-context.py", "check-bug-verdict.py", "load-models.py"),
            "quick-flow.yml": ("resolve-spec.py", "create-branch.py", "init-quick.py", "extract-verdict.py", "load-models.py"),
        }
        for workflow, scripts in expected.items():
            with self.subTest(workflow=workflow):
                content = (ROOT / "workflows" / workflow).read_text(encoding="utf-8")
                self.assertIn("steps.resolve-spec.output.stdout", content)
                self.assertNotIn(".sh", content)
                for script in scripts:
                    self.assertIn(f"python3 {PRESET_PATH}/{script}", content)

    def test_every_command_step_binds_model_from_the_load_models_step(self):
        for workflow in ("workflow.yml", "bugfix-workflow.yml", "quick-flow.yml"):
            content = (ROOT / "workflows" / workflow).read_text(encoding="utf-8")
            with self.subTest(workflow=workflow):
                self.assertIn("id: load-models", content)
                self.assertIn("load-models.py", content)
                self.assertIn("output_format: json", content)

            current_id = ""
            expecting_model = False
            for line_number, line in enumerate(content.splitlines(), start=1):
                stripped = line.strip()
                id_match = re.match(r"-?\s*id:\s*(\S+)", stripped)
                if id_match:
                    current_id = id_match.group(1)
                    continue
                if stripped.startswith("command:"):
                    expecting_model = True
                    continue
                if stripped.startswith("model:"):
                    with self.subTest(workflow=workflow, line=line_number):
                        self.assertTrue(
                            expecting_model,
                            f"{workflow}:{line_number} has a model without a command step",
                        )
                        expected = f"{{{{ steps.load-models.output.data.{current_id}.model }}}}"
                        self.assertEqual(stripped[len("model:"):].strip(), f'"{expected}"')
                    expecting_model = False
            with self.subTest(workflow=workflow):
                self.assertFalse(expecting_model, f"{workflow} has a command step without a model")

    def test_shell_steps_never_interpolate_user_input_or_step_output(self):
        """Shell `run:` lines may only interpolate the engine-validated run id.

        User-supplied spec/issue/file text and step stdout contain arbitrary
        characters; splicing them into a `run:` template makes the engine's
        `/bin/sh -c` execute them as shell syntax (issue #11). Scripts read that
        data from the run directory instead.
        """
        for workflow in ("workflow.yml", "bugfix-workflow.yml", "quick-flow.yml"):
            content = (ROOT / "workflows" / workflow).read_text(encoding="utf-8")
            for line_number, line in enumerate(content.splitlines(), start=1):
                stripped = line.strip()
                if not stripped.startswith("run:"):
                    continue
                for block in re.findall(r"\{\{(.+?)\}\}", stripped):
                    with self.subTest(workflow=workflow, line=line_number):
                        self.assertEqual(
                            block.strip(),
                            "context.run_id",
                            f"{workflow}:{line_number} interpolates untrusted data "
                            f"into a shell command",
                        )

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
