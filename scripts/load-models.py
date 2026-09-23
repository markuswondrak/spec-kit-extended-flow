#!/usr/bin/env python3
"""Expose per-step model overrides for a workflow run.

The optional ``model_config`` input points at a JSON document mapping step ids
to ``{"model": "..."}`` objects. The document is read here rather than through
a shell ``run:`` line so the path is never interpreted as shell syntax (issue
#11). Whatever the document contains is passed through as ``output.data``; a
step id that is absent resolves to ``None`` and the command step falls back to
the agent default, so no fixed step list is needed.
"""

import json
import re
import sys
from pathlib import Path


RUNS_DIR = Path(".specify") / "workflows" / "runs"
RUN_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")

PRESET_DEFAULT_PATH = Path(__file__).resolve().parent.parent / "model.config.json"
PROJECT_OVERRIDE_PATH = Path("model.config.json")


def error(message: str) -> int:
    print(f"ERROR: {message}", file=sys.stderr)
    return 1


class InputError(Exception):
    """Raised when the workflow run inputs cannot be read."""


def load_run_inputs(run_id: str) -> dict:
    if not RUN_ID_PATTERN.fullmatch(run_id):
        raise InputError(f"Invalid run id: {run_id!r}.")
    inputs_path = RUNS_DIR / run_id / "inputs.json"
    try:
        document = json.loads(inputs_path.read_text(encoding="utf-8"))
    except OSError:
        raise InputError(f"Workflow inputs not found: {inputs_path}")
    except json.JSONDecodeError:
        raise InputError(f"Workflow inputs are not valid JSON: {inputs_path}")
    if not isinstance(document, dict) or not isinstance(document.get("inputs"), dict):
        raise InputError(f"Workflow inputs are malformed: {inputs_path}")
    return document["inputs"]


def read_input(inputs: dict, key: str) -> str:
    value = inputs.get(key, "")
    if value is None:
        return ""
    if not isinstance(value, str):
        raise InputError(f"Workflow input {key!r} must be a string.")
    return value


def resolve_config_path(explicit: str) -> Path | None:
    """Return the config file to use, or ``None`` when no override is present.

    Precedence: an explicit ``model_config`` input, then a project-root
    ``model.config.json`` (the reinstall-safe permanent override), then the
    config shipped inside the installed preset.
    """
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise InputError(f"Model config file not found: {explicit}")
        return path
    if PROJECT_OVERRIDE_PATH.is_file():
        return PROJECT_OVERRIDE_PATH
    if PRESET_DEFAULT_PATH.is_file():
        return PRESET_DEFAULT_PATH
    return None


def load_config(path: Path) -> dict:
    """Read *path* and return its parsed contents unchanged.

    The shape is validated so a malformed config fails here with a clear error
    instead of silently falling back to the agent default at a later step.
    """
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        raise InputError(f"Model config file not found: {path}")
    except json.JSONDecodeError:
        raise InputError(f"Model config is not valid JSON: {path}")
    if not isinstance(document, dict):
        raise InputError(f"Model config must be a JSON object: {path}")

    for step_id, entry in document.items():
        if not isinstance(entry, dict):
            raise InputError(f"Model config entry {step_id!r} must be an object: {path}")
        model = entry.get("model", "")
        if model is not None and not isinstance(model, str):
            raise InputError(f"Model config entry {step_id!r}.model must be a string: {path}")
    return document


def main() -> int:
    run_id = sys.argv[1] if len(sys.argv) > 1 else ""
    if not run_id:
        return error("Run id is required.")

    try:
        inputs = load_run_inputs(run_id)
        explicit = read_input(inputs, "model_config")
        config_path = resolve_config_path(explicit)
        models = load_config(config_path) if config_path is not None else {}
    except InputError as exc:
        return error(str(exc))

    sys.stdout.write(json.dumps(models))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        raise SystemExit(1)
    except Exception as exc:
        print(f"ERROR: Unexpected error: {exc}", file=sys.stderr)
        raise SystemExit(1)
