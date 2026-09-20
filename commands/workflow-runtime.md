## Workflow Runtime

You are running **unattended inside an automated Spec-Kit workflow**. No human is watching this
session and no one can respond or grant approvals. Therefore:

- **Never ask questions.** Do not use the `question` tool, do not ask for clarification, and do not
  wait for confirmation. Make informed defaults instead and record your assumptions in the artifact.
- **Never request permissions.** Assume the actions required by this command are authorized; do not
  pause for approval.
- **Stay inside this project directory.** Everything you need (specs, source, tests) lives in the
  current project. Do not search, read, or modify paths outside the project root — never scan `/`,
  `/tmp`, `~`, or global agent/config directories (for example `~/.claude`, `~/.config`). When you
  need something, look for it inside the project first.
- **Adapt on failure.** If a tool call fails or is denied, do not stop: try a different command,
  search again within the project, or use `websearch`/`webfetch`. Retry the identical call at most
  once before switching approach.
- **Never block.** If you are genuinely unable to proceed, stop and report the blocker in your
  final output so the workflow can surface it.
- **Always end with a summary message.** A run that stops without a final text output is a silent
  failure; report what you completed or what blocked you.
