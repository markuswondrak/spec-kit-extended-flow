## Sub-Agent Delegation

Some steps below have **independent work items**. When independent work exists, dispatch each
item as a **delegated sub-agent** in an isolated context and collect the results before
continuing.

**Use the delegation capability you actually have.** Read it from your own session — the tools
you can call, or a sub-agent subcommand your backend documents — not from a lookup that could
be stale. Delegate through whatever primitive exists, using that primitive's own calling
convention. If the primitive is registered but inactive and your backend exposes a way to
activate it, activate it once first.

Before dispatching, **state the primitive you are using** (or that no delegation capability is
available). That keeps the choice visible in the run output instead of implicit.

`.specify/integration.json` (the `default_integration` key, then `integration`) is read only to
look up the hint row below and to report which integration ran. **The key never decides whether
you delegate.** These rows record known-good calling conventions for common backends; they are
hints, not a gate. A missing row never means sequential, and a present row never guarantees the
primitive is available.

| integration | delegation primitive (hint) |
|-------------|-----------------------------|
| `claude` | `Task` tool — spawn a sub-agent in an isolated context |
| `copilot` | `runSubagent` (VS Code) or the Copilot CLI sub-agent process; project agents live under `.github/agents/` |
| `opencode` | `task` tool with `subagent_type` |
| `pi` | `subagent` tool from the `pi-subagents` extension; call `subagents_enable` once first if that is the registered entry point |

If no delegation capability exists — no sub-agent tool and no documented sub-agent subcommand —
execute the work items **sequentially in this same context**. Sequential execution is always
correct; never emit a mechanism your backend cannot perform.

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
and sequential remains a valid, correct execution path when no primitive exists.
