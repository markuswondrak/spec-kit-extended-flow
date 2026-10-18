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
    "preserve-quick-review.py",
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

    def test_every_command_step_prefers_its_model_entry_then_falls_back_to_default(self):
        """The workflow binding expresses step entry > default > agent default.

        The workflow engine applies the ``default`` filter. Omitting any
        additional fallback deliberately leaves the integration's agent default
        in effect when neither config entry supplies a model.
        """
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
                        step_model = f"steps.load-models.output.data.{current_id}.model"
                        default_model = "steps.load-models.output.data.default.model"
                        expected = f"{{{{ {step_model} | default({default_model}) }}}}"
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

    def test_feature_flow_gates_between_analyze_and_implement(self):
        content = (ROOT / "workflows" / "workflow.yml").read_text(encoding="utf-8")
        analyze = content.index("command: speckit.analyze")
        gate = content.index("id: analyze-gate")
        implement = content.index("command: speckit.implement")
        self.assertLess(analyze, gate)
        self.assertLess(gate, implement)
        gate_block = content[gate:implement]
        self.assertIn("type: gate", gate_block)
        self.assertIn("options: [approve, reject]", gate_block)
        self.assertIn("on_reject: abort", gate_block)

    def test_quick_flow_uses_the_approved_plan_and_routes_review_failures_to_a_gate(self):
        workflow = (ROOT / "workflows" / "quick-flow.yml").read_text(encoding="utf-8")
        review = (ROOT / "commands" / "speckit.extendedflow.quick-review.md").read_text(encoding="utf-8")
        plan = (ROOT / "commands" / "speckit.extendedflow.quick-plan.md").read_text(encoding="utf-8")

        self.assertNotIn("record-quick-scope.py", workflow)
        self.assertIn("preserve-quick-review.py", workflow)
        self.assertIn("id: quick-review-resolution", workflow)
        for option in ("ship-partial", "escalate", "abort"):
            with self.subTest(option=option):
                self.assertIn(option, workflow)
        self.assertNotIn("stop-on-review-fail", workflow)
        self.assertNotIn("review-failed", workflow)
        self.assertIn("approved plan", review.lower())
        self.assertNotIn("approved-scope.json", review)
        self.assertNotIn("sha-256", review.lower())
        self.assertNotIn("record-quick-scope.py", plan)
        self.assertIn("Deferred", review)
        self.assertIn("Out of Scope", review)
        self.assertIn("Never exit nonzero solely because the verdict is FAIL", review)
        for heading in ("## In Scope", "## Deferred", "## Out of Scope"):
            with self.subTest(heading=heading):
                self.assertIn(heading, plan)

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

    def test_preamble_reads_integration_json_only_for_hints_and_reporting(self):
        text = self.preamble_text()
        self.assertIn(".specify/integration.json", text)
        self.assertIn("default_integration", text)

    def test_hint_table_lists_known_integrations_without_gating_delegation(self):
        """Rows are hints; the integration key must never decide *whether* to delegate."""
        text = self.preamble_text()
        for key in ("claude", "copilot", "opencode", "pi"):
            with self.subTest(integration=key):
                self.assertIn(f"`{key}`", text)
        self.assertIn("sequentially", text)
        self.assertIn("hints, not a gate", text)
        self.assertNotIn("If your integration is not listed above", text)

    def test_preamble_makes_the_chosen_primitive_observable(self):
        text = self.preamble_text()
        self.assertIn("state the primitive you are using", text)

    def test_preamble_is_mechanism_neutral_outside_the_hint_table(self):
        """Backend-specific tool names and paths may only appear on hint rows."""
        text = self.preamble_text()
        mechanisms = ("Task", "runSubagent", "subagent", "task", ".github/agents/")
        for line_number, line in enumerate(text.splitlines(), start=1):
            if any(token in line for token in mechanisms):
                with self.subTest(line=line_number, text=line):
                    self.assertIn("|", line, f"line {line_number} leaks a backend mechanism outside the hint table")
        self.assertNotIn("~/.copilot", text)
        self.assertNotIn("~/.claude", text)


class AnalysisReportStaticContracts(unittest.TestCase):
    """The analyze wrap must persist the report without duplicating an existing layer."""

    PRESET_DIR = ROOT / "presets" / "analysis-report"
    WRAPPER = PRESET_DIR / "commands" / "speckit.analyze.md"

    def test_preset_wraps_analyze_exactly_once(self):
        manifest = (self.PRESET_DIR / "preset.yml").read_text(encoding="utf-8")
        self.assertEqual(manifest.count('name: "speckit.analyze"'), 1)
        self.assertEqual(manifest.count('file: "commands/speckit.analyze.md"'), 1)
        self.assertEqual(manifest.count('strategy: "wrap"'), 1)
        command_files = sorted(path.name for path in (self.PRESET_DIR / "commands").glob("*.md"))
        self.assertEqual(command_files, ["speckit.analyze.md"])

    def test_wrapper_persists_the_report_under_feature_dir(self):
        text = self.WRAPPER.read_text(encoding="utf-8")
        self.assertIn("{CORE_TEMPLATE}", text)
        self.assertIn("FEATURE_DIR/analysis.md", text)
        self.assertIn("supersedes the read-only", text.lower())
        # The wrapper states the target and the override, nothing else: the
        # command already defines FEATURE_DIR and its own read-only contract.
        self.assertLessEqual(len([line for line in text.splitlines() if line.strip()]), 8)

    def test_bundle_installs_the_wrap_at_the_highest_precedence(self):
        """A wrap only encloses the layers below it, so it needs the lowest priority number."""
        bundle = (ROOT / "bundle.yml").read_text(encoding="utf-8")
        self.assertIn('id: "analysis-report"', bundle)
        priorities: dict[str, int] = {}
        component_id = ""
        for line in bundle.splitlines():
            stripped = line.strip()
            if stripped.startswith("- id: "):
                component_id = stripped.split('"')[1]
            elif stripped.startswith("priority: ") and component_id:
                priorities[component_id] = int(stripped.split(":")[1])
                component_id = ""
        self.assertIn("analysis-report", priorities)
        self.assertIn("spec-kit-extended-flow", priorities)
        self.assertLess(priorities["analysis-report"], priorities["spec-kit-extended-flow"])

    def test_gate_and_preset_are_documented(self):
        self.assertIn("analyze-gate", (ROOT / "docs" / "flows.md").read_text(encoding="utf-8"))
        self.assertIn(
            "### Analysis report",
            (ROOT / "docs" / "reference.md").read_text(encoding="utf-8"),
        )


class WorkflowIntegrationContract(unittest.TestCase):
    def test_workflows_do_not_gate_on_an_advisory_integration_list(self):
        """`requires.integrations` is not enforced by the engine, so the flows must not declare it."""
        for workflow in sorted((ROOT / "workflows").glob("*.yml")):
            with self.subTest(workflow=workflow.name):
                text = workflow.read_text(encoding="utf-8")
                self.assertEqual(re.findall(r"^  integrations:", text, re.MULTILINE), [])
