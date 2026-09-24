## Sub-Agent Delegation

Some steps below have **independent work items**. When independent work exists, dispatch each
item as a **delegated sub-agent** in an isolated context and collect the results before
continuing. Use your integration's sub-agent / task / subprocess primitive.

Determine your integration **deterministically** from `.specify/integration.json` (read the
`default_integration` key, then fall back to `integration`). Do not guess the backend from file
contents, paths, or tool availability. Match the key against this table:

| integration | dispatch primitive |
|-------------|--------------------|
| `claude` | `Task` tool — spawn a sub-agent in an isolated context |
| `copilot` | `runSubagent` (VS Code) or the Copilot CLI sub-agent process; project agents live under `.github/agents/` |
| `opencode` | `task` tool with `subagent_type` |

If your integration is not listed above, or has no sub-agent primitive, execute the work items
**sequentially in this same context**. Sequential execution is always correct — never emit a
mechanism your backend cannot perform.

Parallelism by command:

| Command | What runs in parallel |
|---------|-----------------------|
| `plan` | Phase 0 research unknowns; Phase 1 artifacts (`data-model`, `contracts/`, `quickstart`) |
| `implement` | `[P]` tasks within the same phase; context loading |
| `analyze` | The detection passes |
| `tasks` | Document loading; per-user-story task generation |
| `specify` | Quality validation checklist generation |
| `checklist` | Feature context loading (spec, plan, tasks) |
| `clarify` | Ambiguity scan categories |
| `taskstoissues` | Issue creation (batched) |

Delegation only changes **how** existing steps execute — the core command logic is unchanged,
and sequential remains a valid, correct execution path.
