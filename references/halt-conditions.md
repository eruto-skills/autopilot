# Halt Conditions — Why and when the loop stops itself

The reflex in autonomous agents is to keep going. That reflex is what produces hours of work that needs to be thrown away. This page is the contract for when the loop must stop and ask, instead of retrying.

## The four exit statuses

Every iteration of `RUN.md` ends with **exactly one** of these tags on the last line. The wrapper (`/loop` / `/schedule` / cron + Stop hook) parses this to decide whether to fire the next iteration.

| Status | Meaning | What the wrapper does |
|---|---|---|
| `<status>DONE</status>` | All `passes: true` in PLAN.md | Stop. Notify success. |
| `<status>CONTINUE</status>` | Useful progress this iteration; more to do | Fire next iteration |
| `<status>NEEDS_HUMAN</status>` | Premise or scope is unclear; humans must decide | Stop. Notify. Do not retry. |
| `<status>BLOCKED</status>` | 3 consecutive failures, budget cap hit, or anti-pattern detected | Stop. Notify. Do not retry. |

No status, or a malformed status, is treated as `BLOCKED`.

## Why two stop-modes? `NEEDS_HUMAN` vs `BLOCKED`

- `NEEDS_HUMAN` is for **input-side problems**: the question is wrong or ambiguous. Resolution: the human edits PLAN.md or answers an open question.
- `BLOCKED` is for **execution-side problems**: the agent can't make the task pass with the current premise. Resolution: the human investigates — usually the acceptance test is wrong, the dependencies are misaligned, or the task is too big.

The distinction matters because they call for different recovery actions. Collapsing them into "stop and tell me" loses signal.

## The truth-bias problem (yhei_hei)

> LLMモデルは前提のゴールが間違っているとどうしようもなくなる性質「真実バイアス」がある。... 「連続3回テスト失敗で一時停止」という指示文をいれておく。これだけでも暴走のほとんどは防げる。
> — [@yhei_hei](https://x.com/yhei_hei/status/1938552898742313305)

LLMs assume the user's goal is achievable as stated. When it isn't — because of a wrong premise, a missing dependency, a scope mismatch — the model will keep grinding, often for hours, often producing increasingly elaborate ways to fake satisfaction of the criterion.

The fix is not "make the model smarter". The fix is a hard rule: **3 consecutive failures on the same task = `BLOCKED`**, no exceptions.

Implementation lives in `templates/RUN.md` Step 5b. If the user asks you to relax this, push back — this rule alone prevents the majority of overnight-run disasters.

## The ambiguity rule (Findy / SIOS / yhei_hei)

> 指示に不明な点や曖昧な点がある場合、作業を進めずに質問を返してください。
> — [Findy CLAUDE.md暴走防止運用](https://tech.findy.co.jp/entry/2025/12/06/070000)

The default in interactive Claude Code is "try to be helpful, guess if needed". For autonomous runs, this default is wrong. Wrong guesses cost hours; waiting costs seconds.

The Step 2 premise check in `RUN.md` enforces this. Any of:

- Acceptance criterion is not user-observable
- Required dependency missing/changed
- Description and acceptance disagree
- Task implies scope expansion

…triggers `NEEDS_HUMAN`. Do not relax these in templates without a written reason.

## Anti-patterns that trigger immediate `BLOCKED`

Some behaviors are so dangerous they shouldn't even get the 3-failure budget. From `RUN.md` Step "Anti-patterns":

- Editing PLAN.md to lower the bar so a failing test passes
- Marking `passes: true` without running the acceptance check
- Using `--no-verify` to skip hooks
- Running `git add -A` or `git add .` (Findy's lesson: this is how unrelated files get committed)
- Pivoting silently to a "better" task that wasn't in PLAN.md
- Adding mocks/stubs to satisfy a user-observable acceptance test
- "Just one more try" after 3 failures

Each of these has produced specific real-world failures in prior runs (cited sources in [prior-art](prior-art.md)). They aren't theoretical.

## Budget caps

Caps in `BUDGET.md` are checked at Step 0 of every iteration:

- `max_iterations` — total loops
- `max_cost_usd` — manual or `/cost`-tracked
- `max_wallclock_h` — since first iteration's `started_at`
- `min_progress_iterations` — if this many iterations have flipped zero tasks to `passes: true`, emit `BLOCKED` (anti-stuck guard)

Exceeding any cap → `BLOCKED`. Do not "almost done, one more iteration" past a cap. The cap exists because past-you decided this run was worth at most that much. Trust past-you.

## What to do after a halt

When you see `BLOCKED` or `NEEDS_HUMAN`:

1. Read the iteration's last response (it explains why).
2. Read the affected task's `notes` in PLAN.md (the failure history).
3. Recent LESSONS.md entries — sometimes the agent already wrote down what's wrong.
4. Decide:
   - **Premise wrong** → edit PLAN.md (fix the acceptance criterion, add an Open question, split the task)
   - **Dependency wrong** → fix the environment, then resume
   - **Out of scope** → mark the task `passes: true` if no longer needed, or move it to a new run
   - **Acceptance test wrong** → rewrite it concretely ([completion-criteria](completion-criteria.md))
5. Resume by re-running the same launch command. The next iteration's Step 0 will re-read PLAN.md and pick up.

If you find yourself adjusting halt conditions to make a run "finish", stop. The halt is doing its job. The problem is upstream.

## Friction archive

Discoveries from dogfood and production runs that the templates encode. If you regenerate templates by hand, keep these:

### Scope of the git check

RUN.md Step 0.4 runs `git status --porcelain` and filters to the **active task's scope** (paths in description + acceptance + notes). Pre-existing dirty state outside that scope must NOT trigger `NEEDS_HUMAN`. Original draft checked the whole tree, which false-positives immediately in any multi-project workspace. Found during the 2026-05-13 dogfood run (Iteration 1).

### WSL quoting from Windows hosts

When acceptance tests need to run a multi-line bash script through WSL from a Windows host, use the **heredoc form**:

```powershell
wsl.exe -- bash << 'EOF'
set -e
# multi-line script here
EOF
```

NOT the `-c` form:

```powershell
wsl.exe -- bash -c 'set -e
multi-line script with $(...) and "quotes"'   # BROKEN — quoting mangles
```

The `-c` form chokes on `set -e` + command-substitution `$(...)` + `2>&1` combinations in unpredictable ways. The heredoc passes the script verbatim. Found during the 2026-05-13 dogfood run (Iteration 2, T02). The premise check in RUN.md Step 2 calls this out for WSL acceptance tests.

### Acceptance assumes repo state

Acceptance criteria of the form "`git diff <file>` shows only X changed" require `<file>` to be **git-tracked**. On untracked files the diff is empty and the check is degenerate (always passes vacuously, or always fails depending on framing). RUN.md Step 2 precondition probes catch this; if you write an acceptance criterion that depends on tracked state, verify the file is tracked before approving the PLAN.md. Found during the 2026-05-13 dogfood run (Iteration 3, T03).
