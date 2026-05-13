---
name: autopilot
description: "Scaffold a long-running, hands-off Claude Code session. Generates a plan with user-observable completion criteria, a deterministic loop body, cross-run lesson memory, and hard budget/iteration ceilings — then hands off to /loop (interactive) or /schedule (remote cron). Trigger on: \"run this overnight\", \"keep working until X\", \"autonomous session\", \"long-running task\", \"自走\", \"放置で\", \"寝てる間に\". For one-shot tasks use /loop or /schedule directly; this skill is for runs that need a plan, a halt-if-unclear contract, and post-mortem review."
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task
argument-hint: [task description]
---

# autopilot

Scaffolds an unattended Claude Code session that won't burn money on the wrong problem. Layers three regimens on top of Anthropic's official `/ralph-loop` plugin and the bundled `/loop` skill:

1. **User-observable completion criteria** — the agent can't fake "done"
2. **Deterministic stack** — re-read the plan + lessons every iteration so context never bloats
3. **Halt-if-unclear default** — 3 consecutive failures or any premise drift triggers a stop, not another retry

## When to use this skill vs alternatives

| Situation | Use |
|---|---|
| Single repetitive check, fixed interval, no plan needed | `/loop` directly |
| Cloud cron, ≥1h interval, no laptop | `/schedule` (Routines) directly |
| Pure Ralph-style "DONE" terminator, one prompt file | `/ralph-loop` plugin directly |
| **Multi-step task, needs plan + completion contract + lessons memory** | **this skill** |
| Task definition is already crystal-clear and short | skip the skill, just write a prompt |

## Workflow

1. **Parse the request** — capture the task description from `$ARGUMENTS`. If empty, ask the user for it in one short turn
2. **Triage scope** — before any interview, decide if the task warrants this skill at all:
   - If `$ARGUMENTS` describes a single-file change, a one-shot script, or anything you could finish in under ~5 minutes interactively → tell the user "this looks too small for autopilot; suggest doing it directly or via `/ralph-loop`". Continue only if the user explicitly says to proceed (dogfood / familiarisation).
   - If `$ARGUMENTS` is empty → ask for the task in one turn before continuing.
3. **Interview** — gather (and write down verbatim) **five** items. The user has already volunteered some of them in `$ARGUMENTS` — only ASK for what's missing. **Goal and Completion criterion are different things**; a task description is NOT an acceptance test. Always confirm acceptance separately.
   - **Goal**: 1–3 sentence task description. (Almost always already in `$ARGUMENTS`.)
   - **Completion criterion**: must be **user-observable** behavior, not architectural. Reject answers like "DDD layers built" or "tests pass without naming which tests"; insist on "user can register/edit/delete rules in browser with real DB persistence" or "`npm test -- auth/` exits 0 AND screenshot tmp/login.png shows dashboard". → [completion-criteria](references/completion-criteria.md). **Even if the user wrote a Goal, ask for Completion criterion — they're not the same.**
   - **Budget**: `max_iterations` (default 25), `max_cost_usd` (default 50), `max_wallclock_h` (default 8). For tiny tasks the user can accept defaults with one click.
   - **Mode**: `interactive` (`/loop` in the current session), `local-cron` (atani-style with 4-walls handling), or `cloud` (`/schedule` Routines, min 1h interval) → [modes](references/modes.md)
   - **Commit authorization**: `auto_commit: yes` (loop commits on every passing task, per RUN.md step 5a) or `auto_commit: no` (loop only updates PLAN.md and prints a "ready to commit: T<id>" hint; user runs git commands themselves). Default `no` — this aligns with the global Claude Code policy of "only commit when explicitly requested". Persist the chosen value into `BUDGET.md`. **Skipping this question silently is a bug** — every run touches git; user must decide once.
   - **Fast-path (recommended for small tasks)**: present a single `AskUserQuestion` with all five items pre-filled from defaults + your reading of `$ARGUMENTS`, and let the user accept or override. Five separate question turns is overkill for one-file changes.
4. **Pre-flight checks** (BEFORE writing any artifacts — fail fast):
   - **Resolve "the current project"**: `git rev-parse --show-toplevel` from cwd. If cwd is inside a multi-skill workspace and the user's task only touches a subdirectory (e.g., `eruto-skills/autopilot/`), ask whether artifacts go at the workspace root or the subdirectory root. **Print the chosen `.claude/autopilot/` path and get explicit confirmation before writing.**
   - Git working tree is clean *within the task's stated scope* (the union of paths implied by the task description and any acceptance tests already known). Pre-existing dirty state outside the task's scope is OK. → see [halt-conditions](references/halt-conditions.md) §"Scope of the git check".
   - For `local-cron` / `cloud` modes: `--dangerously-skip-permissions` will be used, so a sandbox (devcontainer / Docker / cco wrapper) is recommended. Warn the user if not detected.
   - For `cloud` mode: confirm the Routines plan can handle the budget (min interval 1h, max session length per Anthropic plan).
5. **Generate artifacts** under the confirmed `.claude/autopilot/` path:
   - `PLAN.md` — task list with `passes: false/true`, priority, user-observable acceptance test per task → [templates/PLAN.md](templates/PLAN.md)
   - `RUN.md` — the loop body. **Customize per task**, do not just copy the template verbatim. Inject: (a) the project-specific acceptance test runners declared in "Project Integration" below, (b) any task-class hints from `$ARGUMENTS` (e.g., "this task involves WSL — see references/halt-conditions.md §\"WSL quoting\""). → [templates/RUN.md](templates/RUN.md)
   - `LESSONS.md` — Reflexion-style cross-iteration memory. **Loop-writes-only** by contract: only the running loop appends entries (humans should edit PLAN.md "Open questions" instead). The file may contain one seed entry from this scaffolding step describing the initial scope, marked as "scaffold" → [templates/LESSONS.md](templates/LESSONS.md)
   - `BUDGET.md` — caps, counters, and the `auto_commit` flag captured in step 3 → [templates/BUDGET.md](templates/BUDGET.md)
   - **After writing, print a tree listing of the destination** so the user sees exactly what landed where.
6. **Plan review with user** — show the generated PLAN.md and confirm:
   - Each acceptance test is genuinely user-observable (re-check; this is where most runs die)
   - Tasks are sequenced so each can be verified independently
   - No task hides "ambiguous" sub-decisions that should be resolved up front
7. **Launch instruction (do NOT auto-launch)** — print the exact command the user runs, **with OS-appropriate path separators**:
   - Interactive (any OS): `/loop @.claude/autopilot/RUN.md` (Claude Code accepts forward slashes on Windows too — verified)
   - Local-cron: see [modes](references/modes.md) for the 4-walls cron recipe. On Windows the equivalent involves `pwsh` + Task Scheduler — modes.md covers this.
   - Cloud: `/schedule "Run the autopilot loop" --prompt @.claude/autopilot/RUN.md --interval 1h --max-iterations <N>`
   - **Honesty note**: there is no first-class `/ralph-loop` "integration" — the plugin is conceptual prior art. If the user wants its exact UX (single PROMPT.md, "DONE" termination, `--max-iterations` argument) without autopilot's plan/lessons regimen, point them at the plugin directly.
8. **Status / resume** — when the user re-invokes this skill on a project with an existing `.claude/autopilot/`:
   - Summarize PLAN.md progress (X of Y `passes: true`), the last 5 LESSONS.md entries, and BUDGET.md burn.
   - If the last run ended on `NEEDS_HUMAN` or `BLOCKED`, surface the reason verbatim from the iteration's notes and propose either resolution or scope change before resuming.
9. **End-of-run post-mortem** — fires automatically when the loop emits `<status>DONE</status>` (or the user manually stops it):
   - Read PLAN.md, LESSONS.md, BUDGET.md.
   - Produce a 5-line summary: tasks shipped, iterations used, dollars burned, lessons captured, follow-ups.
   - Offer to promote any durable rule from LESSONS.md into `CLAUDE.md` (Compounding Engineering — see [prior-art](references/prior-art.md)). Default to asking, not auto-applying.
   - If `auto_commit: no` and there are uncommitted task changes, list them and stage a single `git commit` command the user can run.
   - **Interactive-mode caveat**: when the user drives iterations by hand in a chat session (rather than via `/loop` or cron), the `<status>...</status>` tags are awkward — there's no wrapper parsing them. In this case the loop body just declares the status in plain English and the user/Claude decides whether to continue. The tags are still useful as a self-discipline marker.

## Status vocabulary (used in RUN.md output)

Every loop iteration ends by emitting exactly one of:

- `<status>DONE</status>` — all tasks in PLAN.md are `passes: true`, no follow-up
- `<status>CONTINUE</status>` — work made progress, more iterations needed
- `<status>NEEDS_HUMAN</status>` — premise is unclear or scope expanded; humans must decide before resuming
- `<status>BLOCKED</status>` — 3 consecutive failures on the current task, or a budget cap was hit

The Stop hook (or the cron wrapper) parses these to decide whether to fire the next iteration. → [halt-conditions](references/halt-conditions.md)

## Design rules baked into the templates

These are not suggestions; the templates enforce them. If you regenerate by hand, keep them:

- **One task per iteration.** Re-iterate from the top of PLAN.md every loop. (Huntley: *"one item per loop. I need to repeat myself here—one item per loop."*)
- **Re-read PLAN.md + LESSONS.md verbatim at the top of every iteration** (deterministic stack allocation).
- **Subagents for research/design/review only; never for build/test of the main artifact.** Builds need backpressure — one at a time.
- **Acceptance test must be runnable as a command or as a 1-sentence user-observable check** (screenshot, browser interaction, curl response, file diff). No "the code is well-structured".
- **Three consecutive failures on the same task → `BLOCKED`.** Do not retry a fourth time. Do not pivot silently — that's how truth-bias loops destroy projects.
- **Ambiguity → `NEEDS_HUMAN`, not a guess.** It is cheaper to wait than to undo (Findy's lesson, yhei_hei's "truth bias").
- **Commit on every passing task.** Per-step snapshots are the recovery mechanism.
- **LESSONS.md entries are 1–3 lines, dated, framed as durable rules** — not narrative diary.

## Project Integration

### Plan placement (customize per project)

Default location is `.claude/autopilot/` at the project root. Override here if you want the artifacts elsewhere (e.g., a `runbooks/` directory tracked in git).

### Acceptance test runners (customize per project)

If your project has standard test commands, declare them here so PLAN.md acceptance tests can reference them. Example:

```markdown
- Unit/integration: `npm test`
- Type check: `npm run typecheck`
- E2E browser: `npm run test:e2e`
- Visual check: write screenshots to `tmp/autopilot-screens/`
```

If not defined, the skill will ask per task what command (or manual check) constitutes "passing".

### CLAUDE.md promotion (optional)

After a run ends, if `LESSONS.md` contains rules generalizable to the whole project, the skill offers to promote them into `CLAUDE.md` (compounding engineering). To disable the prompt, add:

```markdown
autopilot.promote_to_claude_md: never
```

### Cross-Skill Integration

- **review-content / review**: after a `DONE` run, optionally hand off to a review skill before merging
- **research-note**: for tasks that need upfront external research, run research-note first and reference the output from PLAN.md

## Dependencies

- Anthropic Claude Code with `/loop` (built-in) and optionally `/schedule` (Routines)
- For `local-cron` mode: `expect`, `caffeinate` (macOS) or equivalent, a sandbox (devcontainer / Docker / cco)
- The `/ralph-loop` plugin (optional but recommended) — `anthropics/claude-code/plugins/ralph-wiggum`

## See also

- [completion-criteria](references/completion-criteria.md) — how to write a user-observable acceptance test
- [halt-conditions](references/halt-conditions.md) — the truth-bias problem and the status vocabulary
- [modes](references/modes.md) — interactive / local-cron / cloud trade-offs
- [prior-art](references/prior-art.md) — which pattern came from where
