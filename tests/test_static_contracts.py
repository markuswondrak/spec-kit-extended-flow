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

    def test_quick_flow_plans_and_gates_before_implementing(self):
        content = (ROOT / "workflows" / "quick-flow.yml").read_text(encoding="utf-8")
        self.assertIn("command: speckit.extendedflow.quick-plan", content)
        plan_index = content.index("command: speckit.extendedflow.quick-plan")
        gate_index = content.index("id: quick-plan-gate")
        implement_index = content.index("command: speckit.extendedflow.quick-implement")
        self.assertLess(plan_index, gate_index)
        self.assertLess(gate_index, implement_index)
        self.assertIn("on_reject: abort", content)

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


class SubAgentDelegationStaticContracts(unittest.TestCase):
    PRESET_DIR = ROOT / "presets" / "sub-agent-delegation"
    PREAMBLE = PRESET_DIR / "commands" / "sub-agent-delegation.md"
    REGISTERED_COMMANDS = (
        "speckit.specify",
        "speckit.plan",
        "speckit.tasks",
        "speckit.analyze",
        "speckit.implement",
        "speckit.checklist",
        "speckit.clarify",
        "speckit.taskstoissues",
    )

    def preamble_text(self) -> str:
        return self.PREAMBLE.read_text(encoding="utf-8")

    def test_preset_registers_one_shared_preamble_via_prepend(self):
        manifest = (self.PRESET_DIR / "preset.yml").read_text(encoding="utf-8")
        self.assertEqual(manifest.count('file: "commands/sub-agent-delegation.md"'), len(self.REGISTERED_COMMANDS))
        self.assertEqual(manifest.count('strategy: "prepend"'), len(self.REGISTERED_COMMANDS))
        for command in self.REGISTERED_COMMANDS:
            with self.subTest(command=command):
                self.assertIn(f'name: "{command}"', manifest)
        command_files = sorted(path.name for path in (self.PRESET_DIR / "commands").glob("*.md"))
        self.assertEqual(command_files, ["sub-agent-delegation.md"])

    def test_preset_version_matches_the_bundle(self):
        delegation = (self.PRESET_DIR / "preset.yml").read_text(encoding="utf-8")
        bundle = (ROOT / "bundle.yml").read_text(encoding="utf-8")
        self.assertIn('id: "sub-agent-delegation"', bundle)
        delegation_version = re.search(r'^  version: "([^"]+)"', delegation, re.MULTILINE)
        bundle_version = re.search(r'^  version: "([^"]+)"', bundle, re.MULTILINE)
        self.assertIsNotNone(delegation_version)
        self.assertIsNotNone(bundle_version)
        self.assertEqual(delegation_version.group(1), bundle_version.group(1))

    def test_preamble_selects_the_integration_deterministically(self):
        text = self.preamble_text()
        self.assertIn(".specify/integration.json", text)
        self.assertIn("default_integration", text)

    def test_mapping_covers_verified_integrations_and_sequential_fallback(self):
        text = self.preamble_text()
        for key in ("claude", "copilot", "opencode"):
            with self.subTest(integration=key):
                self.assertIn(f"`{key}`", text)
        self.assertIn("sequentially", text)

    def test_preamble_is_mechanism_neutral_outside_the_mapping_table(self):
        """Backend-specific tool names and paths may only appear on map rows."""
        text = self.preamble_text()
        for line_number, line in enumerate(text.splitlines(), start=1):
            if "runSubagent" in line or ".github/agents/" in line:
                with self.subTest(line=line_number):
                    self.assertIn("|", line, f"line {line_number} leaks a backend mechanism outside the map")
        self.assertNotIn("~/.copilot", text)
        self.assertNotIn("~/.claude", text)
