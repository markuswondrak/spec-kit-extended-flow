"""Black-box contracts for runtime helpers shipped in the preset."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"


class RuntimeScriptTestCase(unittest.TestCase):
    def run_script(self, name, *args, cwd, env=None):
        environment = os.environ.copy()
        if env:
            environment.update(env)
        return subprocess.run(
            [sys.executable, str(SCRIPTS / name), *args],
            cwd=cwd,
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def write_command(self, directory, name, source):
        path = Path(directory) / name
        path.write_text("#!/usr/bin/env python3\n" + textwrap.dedent(source), encoding="utf-8")
        path.chmod(0o755)
        return path

    def make_feature(self, root, feature_directory="specs/001-test"):
        (root / ".specify/workflows/runs/run-1").mkdir(parents=True)
        (root / feature_directory).mkdir(parents=True)
        (root / ".specify/feature.json").write_text(
            json.dumps({"feature_directory": feature_directory}) + "\n", encoding="utf-8"
        )
        return root / feature_directory

    def write_run_inputs(self, root, run_id="run-1", **inputs):
        run_directory = root / ".specify/workflows/runs" / run_id
        run_directory.mkdir(parents=True, exist_ok=True)
        (run_directory / "inputs.json").write_text(
            json.dumps({"inputs": inputs}) + "\n", encoding="utf-8"
        )
        return run_directory


class ResolveSpecTests(RuntimeScriptTestCase):
    def test_spec_stdout_has_the_contractual_blank_final_line(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_run_inputs(root, spec="Build an API")
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)
            resolved = (root / ".specify/workflows/runs/run-1/resolved-spec.txt").read_bytes()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"Build an API\n\n")
        self.assertEqual(resolved, b"Build an API\n\n")
        self.assertEqual(result.stderr, b"")

    def test_file_issue_and_spec_are_concatenated_in_input_order(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            spec_file = root / "request.md"
            spec_file.write_bytes(b"File request\n\n")
            bin_directory = root / "bin"
            bin_directory.mkdir()
            self.write_command(
                bin_directory,
                "gh",
                """
                import sys
                sys.stdout.write("# Issue title\\n\\nIssue body\\n")
                """,
            )
            self.write_run_inputs(root, spec="Plain request", file=str(spec_file), issue="42")
            result = self.run_script(
                "resolve-spec.py",
                "run-1",
                cwd=root,
                env={"PATH": f"{bin_directory}:{os.environ['PATH']}"},
            )

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"File request\n# Issue title\n\nIssue body\nPlain request\n\n")
        self.assertEqual(result.stderr, b"")

    def test_shell_metacharacters_are_passed_through_verbatim(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            payload = "Use `OptionList` and $(touch pwned) and [n]"
            self.write_run_inputs(root, spec=payload)
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

            pwned = (root / "pwned").exists()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, payload.encode() + b"\n\n")
        self.assertFalse(pwned)

    def test_missing_file_reports_only_a_stderr_error(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            missing = root / "missing.md"
            self.write_run_inputs(root, file=str(missing))
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, f"ERROR: Spec file not found: {missing}\n".encode())

    def test_non_regular_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            directory = root / "not-a-file"
            directory.mkdir()
            self.write_run_inputs(root, file=str(directory))
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, f"ERROR: Spec file not found: {directory}\n".encode())

    @unittest.skipUnless(hasattr(os, "mkfifo"), "FIFOs require POSIX")
    def test_fifo_is_rejected_without_waiting_for_a_writer(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            fifo = root / "request.fifo"
            os.mkfifo(fifo)
            self.write_run_inputs(root, file=str(fifo))
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, f"ERROR: Spec file not found: {fifo}\n".encode())

    def test_missing_input_reports_only_a_stderr_error(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_run_inputs(root)
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(
            result.stderr,
            b"ERROR: No specification provided. Set at least one of: --input spec, --input file, or --input issue.\n",
        )

    def test_missing_run_inputs_reports_only_a_stderr_error(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            result = self.run_script("resolve-spec.py", "run-1", cwd=temporary_directory)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: Workflow inputs not found:", result.stderr)

    def test_issue_must_be_numeric(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_run_inputs(root, issue="42; rm -rf /")
            result = self.run_script("resolve-spec.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"ERROR: Invalid issue number: '42; rm -rf /'.\n")

    def test_issue_requires_gh_without_writing_stdout(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            empty_path = root / "empty-path"
            empty_path.mkdir()
            self.write_run_inputs(root, issue="42")
            result = self.run_script(
                "resolve-spec.py", "run-1", cwd=root, env={"PATH": str(empty_path)}
            )

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: GitHub CLI (gh) is required", result.stderr)


class RuntimeHelperTests(RuntimeScriptTestCase):
    def test_create_branch_uses_default_and_custom_prefixes(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bin_directory = root / "bin"
            bin_directory.mkdir()
            self.write_command(
                bin_directory,
                "gh",
                """
                import sys
                assert sys.argv[1:7] == ["issue", "view", "42", "--json", "title", "--jq"]
                print("Add user auth")
                """,
            )
            self.write_command(
                bin_directory,
                "git",
                """
                import sys
                if sys.argv[1:4] == ["show-ref", "--verify", "--quiet"]:
                    raise SystemExit(1)
                assert sys.argv[1:3] == ["checkout", "-b"]
                """,
            )
            env = {"PATH": f"{bin_directory}:{os.environ['PATH']}"}
            self.write_run_inputs(root, issue="42")
            default = self.run_script("create-branch.py", "run-1", cwd=root, env=env)
            empty = self.run_script("create-branch.py", "run-1", "", cwd=root, env=env)
            custom = self.run_script("create-branch.py", "run-1", "fix/", cwd=root, env=env)

        self.assertEqual((default.returncode, default.stdout, default.stderr), (0, b"feature/42-add-user-auth\n", b""))
        self.assertEqual((empty.returncode, empty.stdout, empty.stderr), (0, b"feature/42-add-user-auth\n", b""))
        self.assertEqual((custom.returncode, custom.stdout, custom.stderr), (0, b"fix/42-add-user-auth\n", b""))

    def test_create_branch_missing_issue_is_a_stderr_error(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_run_inputs(root)
            result = self.run_script("create-branch.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"ERROR: Issue number is required.\n")

    def test_create_branch_rejects_a_non_numeric_issue(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            self.write_run_inputs(root, issue="42 --json title")
            result = self.run_script("create-branch.py", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertEqual(result.stderr, b"ERROR: Invalid issue number: '42 --json title'.\n")

    def test_check_converge_returns_exact_verdict_tokens_and_writes_state(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            tasks = feature / "tasks.md"
            tasks.write_text("# Tasks\n", encoding="utf-8")
            snapshot = self.run_script("check-converge.py", "snapshot", "run-1", cwd=root)
            converged = self.run_script("check-converge.py", "check", "run-1", cwd=root)
            tasks.write_text("# Tasks\n\n- [ ] T001 More work\n", encoding="utf-8")
            appended = self.run_script("check-converge.py", "check", "run-1", cwd=root)

            state = (root / ".specify/workflows/runs/run-1/converge-state.txt").read_bytes()

        self.assertEqual(snapshot.returncode, 0)
        self.assertTrue(snapshot.stdout.startswith(b"OK: recorded baseline for "))
        self.assertEqual((converged.returncode, converged.stdout, converged.stderr), (0, b"CONVERGED\n", b""))
        self.assertEqual((appended.returncode, appended.stdout, appended.stderr), (0, b"TASKS_APPENDED\n", b""))
        self.assertEqual(state, b"TASKS_APPENDED\n")

    def test_check_converge_requires_a_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            (feature / "tasks.md").write_text("# Tasks\n", encoding="utf-8")
            result = self.run_script("check-converge.py", "check", "run-1", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: No converge baseline found", result.stderr)

    def test_extract_verdict_selects_the_highest_iteration_and_persists_it(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            (feature / "review-findings-1-FAIL.md").touch()
            (feature / "review-findings-2-PASS.md").touch()
            result = self.run_script("extract-verdict.py", "run-1", cwd=root)
            verdict = (root / ".specify/workflows/runs/run-1/review-verdict.txt").read_bytes()

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"PASS\n", b""))
        self.assertEqual(verdict, b"PASS\n")

    def test_extract_verdict_rejects_unrecognized_verdict_tokens(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            (feature / "review-findings-1-MAYBE.md").touch()
            result = self.run_script("extract-verdict.py", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: Invalid review findings filename: review-findings-1-MAYBE.md", result.stderr)

    def test_extract_verdict_rejects_malformed_artifacts_instead_of_using_a_stale_pass(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            (feature / "review-findings-1-PASS.md").touch()
            (feature / "review-findings-2x-FAIL.md").touch()
            result = self.run_script("extract-verdict.py", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: Invalid review findings filename: review-findings-2x-FAIL.md", result.stderr)

    def test_extract_verdict_rejects_conflicting_highest_iteration(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = self.make_feature(root)
            (feature / "review-findings-2-PASS.md").touch()
            (feature / "review-findings-2-FAIL.md").touch()
            result = self.run_script("extract-verdict.py", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: Multiple review findings files for iteration 2", result.stderr)

    def test_init_quick_creates_the_pointer_and_returns_the_directory(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            run_directory = self.write_run_inputs(root)
            (run_directory / "resolved-spec.txt").write_text("Add validation message", encoding="utf-8")
            result = self.run_script("init-quick.py", "run-1", cwd=root)
            pointer = json.loads((root / ".specify/feature.json").read_text(encoding="utf-8"))

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"specs/quick-add-validation-message\n", b""))
        self.assertEqual(pointer, {"feature_directory": "specs/quick-add-validation-message", "type": "quick"})

    def test_init_quick_reuses_an_existing_directory_and_clears_stale_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = root / "specs/quick-existing"
            feature.mkdir(parents=True)
            (feature / "review-findings-1-FAIL.md").write_text("# stale verdict\n", encoding="utf-8")
            (feature / "doc-check.md").write_text("# stale doc check\n", encoding="utf-8")
            foreign = feature / "notes.txt"
            foreign.write_text("keep me\n", encoding="utf-8")
            run_directory = self.write_run_inputs(root)
            (run_directory / "resolved-spec.txt").write_text("existing", encoding="utf-8")
            result = self.run_script("init-quick.py", "run-1", cwd=root)
            pointer = json.loads((root / ".specify/feature.json").read_text(encoding="utf-8"))
            remaining = sorted(path.name for path in feature.iterdir())
            foreign_contents = foreign.read_text(encoding="utf-8")

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"specs/quick-existing\n", b""))
        self.assertEqual(pointer, {"feature_directory": "specs/quick-existing", "type": "quick"})
        self.assertEqual(remaining, ["notes.txt"])
        self.assertEqual(foreign_contents, "keep me\n")

    def test_init_quick_derives_a_safe_slug_from_shell_metacharacters(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            run_directory = self.write_run_inputs(root)
            (run_directory / "resolved-spec.txt").write_text(
                "Rename `login` $(touch pwned) button", encoding="utf-8"
            )
            result = self.run_script("init-quick.py", "run-1", cwd=root)
            pointer = json.loads((root / ".specify/feature.json").read_text(encoding="utf-8"))
            pwned = (root / "pwned").exists()

        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"specs/quick-rename-login-touch-pwned\n")
        self.assertEqual(pointer["type"], "quick")
        self.assertFalse(pwned)

    def test_init_quick_uses_the_issue_title_when_an_issue_is_present(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bin_directory = root / "bin"
            bin_directory.mkdir()
            self.write_command(
                bin_directory,
                "gh",
                """
                print("Add user auth")
                """,
            )
            self.write_run_inputs(root, issue="42")
            result = self.run_script(
                "init-quick.py", "run-1", cwd=root, env={"PATH": f"{bin_directory}:{os.environ['PATH']}"}
            )
            pointer = json.loads((root / ".specify/feature.json").read_text(encoding="utf-8"))

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"specs/42-quick-add-user-auth\n", b""))
        self.assertEqual(pointer, {"feature_directory": "specs/42-quick-add-user-auth", "type": "quick"})

    def test_verify_spec_accepts_alternate_feature_pointer_keys(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            feature = root / "specs/002-alt"
            feature.mkdir(parents=True)
            (feature / "spec.md").write_text("# Spec\n", encoding="utf-8")
            (root / ".specify").mkdir()
            (root / ".specify/feature.json").write_text('{"dir": "specs/002-alt"}\n', encoding="utf-8")
            result = self.run_script("verify-spec.py", cwd=root)

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"Spec verification passed: specs/002-alt/spec.md\n", b""))

    def test_resolve_bug_context_writes_a_bug_pointer(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bug = root / ".specify/bugs/login-timeout"
            bug.mkdir(parents=True)
            (bug / "assessment.md").write_text("# Assessment\n", encoding="utf-8")
            result = self.run_script("resolve-bug-context.py", cwd=root)
            pointer = json.loads((root / ".specify/feature.json").read_text(encoding="utf-8"))

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"login-timeout\n", b""))
        self.assertEqual(pointer, {"feature_directory": ".specify/bugs/login-timeout", "type": "bug"})

    def test_resolve_bug_context_ignores_assessment_directories(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            assessment_directory = root / ".specify/bugs/invalid/assessment.md"
            assessment_directory.mkdir(parents=True)
            result = self.run_script("resolve-bug-context.py", cwd=root)

        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")
        self.assertIn(b"ERROR: No assessment.md found", result.stderr)

    def test_check_bug_verdict_uses_verified_as_the_only_success_token(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bug = root / ".specify/bugs/example"
            bug.mkdir(parents=True)
            (root / ".specify/feature.json").write_text(
                '{"feature_directory": ".specify/bugs/example", "type": "bug"}\n', encoding="utf-8"
            )
            test_report = bug / "test.md"
            test_report.write_text("- **Result**: verified\n", encoding="utf-8")
            verified = self.run_script("check-bug-verdict.py", cwd=root)
            test_report.write_text("- **Result**: partial\n", encoding="utf-8")
            partial = self.run_script("check-bug-verdict.py", cwd=root)
            test_report.write_text("- **Result**:\n  verified\n", encoding="utf-8")
            multiline = self.run_script("check-bug-verdict.py", cwd=root)

        self.assertEqual((verified.returncode, verified.stdout, verified.stderr), (0, b"verified\n", b""))
        self.assertEqual(partial.returncode, 1)
        self.assertEqual(partial.stdout, b"")
        self.assertEqual(partial.stderr, b"partial\nERROR: Bug verification result is 'partial'.\n")
        self.assertEqual(multiline.returncode, 1)
        self.assertEqual(multiline.stdout, b"")
        self.assertIn(b"ERROR: Missing or invalid Result field", multiline.stderr)

    def test_resolve_pr_template_prefers_alphabetical_variants(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            variants = root / ".github/PULL_REQUEST_TEMPLATE"
            variants.mkdir(parents=True)
            (variants / "zulu.md").touch()
            alpha = variants / "alpha.md"
            alpha.touch()
            (root / "PULL_REQUEST_TEMPLATE.md").touch()
            result = self.run_script("resolve-pr-template.py", cwd=root)

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, f"{alpha}\n".encode(), b""))

    def test_resolve_pr_template_ignores_symlinked_variants(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            variants = root / ".github/PULL_REQUEST_TEMPLATE"
            variants.mkdir(parents=True)
            external = root / "external.md"
            external.touch()
            (variants / "alpha.md").symlink_to(external)
            fallback = root / "PULL_REQUEST_TEMPLATE.md"
            fallback.touch()
            result = self.run_script("resolve-pr-template.py", cwd=root)

        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, f"{fallback}\n".encode(), b""))
