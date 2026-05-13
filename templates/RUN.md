# RUN — Autopilot Loop Body

You are running inside an autonomous loop. This file is fed to you at the top of every iteration. The artifacts you read and write live alongside it under `.claude/autopilot/`.

## Step 0 — Deterministic stack (do this EVERY iteration, no exceptions)

1. Read `.claude/autopilot/PLAN.md` in full.
2. Read `.claude/autopilot/LESSONS.md` in full. Treat these as durable rules — apply them; do not re-derive them.
3. Read `.claude/autopilot/BUDGET.md`. If any cap is exceeded, emit `<status>BLOCKED</status>` with the cap name and stop. Do not "just one more try".
4. Run `git status --porcelain`, then **filter to the active task's scope**. The "scope" is the union of paths that appear in the next task's `description` and `acceptance` fields (plus any paths already listed in that task's `notes`). If any in-scope file has uncommitted changes that this session did not make, emit `<status>NEEDS_HUMAN</status>` (someone else is editing the same area). Pre-existing dirty state outside the active task's scope is OK and must NOT trigger NEEDS_HUMAN — multi-project workspaces almost always have unrelated dirty files. → see [halt-conditions](../references/halt-conditions.md) §"Scope of the git check".

## Step 1 — Pick exactly one task

From PLAN.md, select the task with the lowest `priority` whose `passes: false`. **Exactly one. Not two.**

If no such task exists → emit `<status>DONE</status>` and stop.

If PLAN.md "Open questions" is non-empty → emit `<status>NEEDS_HUMAN</status>` and stop.

## Step 2 — Premise check

Before touching code, write a one-sentence summary of what success looks like for this task, derived from the task's `acceptance` field. Read it back to yourself. If any of the following are true, emit `<status>NEEDS_HUMAN</status>` and stop:

- The acceptance criterion is not user-observable (it says "well-structured", "clean", "good", "follows the pattern" — these are not checks).
- A required dependency (file, service, credential, API) is missing or has changed since PLAN.md was written.
- The task's description and acceptance disagree.
- You notice you would need to expand PLAN.md to do this task properly. That is scope drift — surface it, do not do it.

**Probe acceptance preconditions** — before running implementation, check that the *checks themselves* will be runnable when you get to step 4. Examples:

- Acceptance uses `git diff <file>` → confirm `<file>` is git-tracked (not in `.gitignore`, not untracked). If untracked, the diff will be empty and the check is degenerate — surface as `NEEDS_HUMAN` so the user can either track the file or rewrite the criterion.
- Acceptance uses `curl localhost:3000/...` → confirm the server can be started in this environment. If not, NEEDS_HUMAN.
- Acceptance uses a screenshot → confirm a headless browser (Playwright/Chrome) is installed. If not, NEEDS_HUMAN.
- Acceptance uses `psql` → confirm DB connection works. If not, NEEDS_HUMAN.
- Acceptance uses WSL commands from a Windows host → use the **heredoc form** (`wsl.exe -- bash << 'EOF' … EOF`), NOT `wsl.exe -- bash -c '…'`. See [halt-conditions](../references/halt-conditions.md) §"Friction archive: WSL quoting".

This step is the single biggest defense against "truth bias" loops where you grind for hours toward an impossible premise. → see LESSONS for past examples.

## Step 3 — Implement

- You may spawn parallel subagents for **research, design exploration, code review, and document lookup**. Cap: as many as the task needs.
- You may spawn at most **one** subagent (or run yourself) for **build / test / lint of the main artifact** at a time. Concurrent builds create backpressure thrashing.
- Make the smallest change that could plausibly make the acceptance test pass.
- Do NOT change files outside this task's stated scope. If you discover you need to, stop and add an "Open question" to PLAN.md, then emit `<status>NEEDS_HUMAN</status>`.

## Step 4 — Run the acceptance test

Run the exact command(s) or perform the exact check listed in the task's `acceptance` field. **All sub-steps run in the SAME iteration** — you do not split a multi-substep acceptance across iterations (each iteration covers exactly one PLAN.md task, end-to-end).

If a task's acceptance has so many sub-steps that they exceed one iteration's reasonable token budget, that's a PLAN.md design error — split the task into smaller ones (rewrite PLAN.md and emit `<status>NEEDS_HUMAN</status>` rather than barreling through).

Record the outcome in the task's `notes` field with timestamp:

```
- 2026-MM-DD HH:MM PASS  <command> exit 0
- 2026-MM-DD HH:MM FAIL  <command> exit 1: <one-line excerpt of the failure>
```

If the acceptance test does not run cleanly (test runner errored before producing a verdict, screenshot couldn't be taken, etc.), that counts as a **failure**, not as "inconclusive".

## Step 5 — Branch on outcome

### Step 5a — If acceptance passed

1. `git add -p` (or `git add <specific files>` — never `git add -A`, per Findy's lesson).
2. Commit with message `autopilot: T<id> — <task description>`.
3. In PLAN.md, set this task's `passes: true`.
4. If you learned something durable, append a single 1–3 line entry to LESSONS.md:
   ```
   ## 2026-MM-DD
   - Rule: <imperative, durable, project-wide>
   - Why: <one sentence>
   - How to apply: <when this kicks in>
   ```
5. Increment `iterations_used` in BUDGET.md.
6. Emit `<status>CONTINUE</status>` and stop. The next iteration picks up.

### Step 5b — If acceptance failed

1. Append the failure line to the task's `notes` in PLAN.md (see Step 4 format).
2. Count the consecutive failures in this task's `notes`:
   - **1st failure**: revert any partial changes (`git restore .` for untracked or `git reset --hard HEAD` only if no other commits this session). Emit `<status>CONTINUE</status>`.
   - **2nd failure**: same as 1st, but additionally write a one-line hypothesis to `notes` about why the prior attempt failed.
   - **3rd consecutive failure on the same task**: emit `<status>BLOCKED</status>` and stop. Do not attempt a fourth time. The premise or the acceptance test is wrong, and another retry will not surface that.

## Step 6 — Status output is the LAST thing you do

The very last line of your response must be one of:

- `<status>DONE</status>`
- `<status>CONTINUE</status>`
- `<status>NEEDS_HUMAN</status>`
- `<status>BLOCKED</status>`

The outer wrapper (`/loop`, `/schedule`, or the local cron + Stop hook) reads this to decide whether to fire the next iteration. No status = treated as `BLOCKED`.

## Anti-patterns (these are immediate `BLOCKED` triggers, learned from prior runs)

- Editing PLAN.md to lower the bar so a failing test passes
- Marking `passes: true` without running the acceptance check
- Using `--no-verify` to skip hooks
- Running `git add -A` or `git add .`
- Pivoting silently to a "better" task that wasn't in PLAN.md
- Adding mocks/stubs to satisfy a user-observable acceptance test (the whole point is the real behavior)
- "Just one more try" after 3 failures
