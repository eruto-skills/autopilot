# Completion Criteria — How to write acceptance tests autopilot can actually verify

This is the single highest-leverage piece of the skill. A run with a vague acceptance criterion will produce hours of work that *looks* done and isn't. A run with a sharp one ends honestly — either with shipped behavior or with a `BLOCKED` that the human can quickly resolve.

## The rule

**Every task's acceptance criterion must be user-observable.**

User-observable = a human (or a script standing in for a human) can verify the end-to-end behavior without reading the source code. The agent must not be able to satisfy the criterion by writing convincing-looking code alone.

Source: this discipline is most cleanly articulated by jujunjun110's [3-agent loop writeup](https://note.com/jujunjun110/n/n0903bad8b2f2) — *"❌ 『DDDレイヤー構造で構成され、Gateway interface が定義される』 / ✅ 『rules ページで表現ルールの一覧表示・登録・編集・削除ができ、本物のDB に永続化される』"*. Boris Cherny's TDD prompts from claudefa.st enforce the same principle on the test-suite side.

## Concrete vs abstract — side-by-side

| ❌ Abstract / model-fakeable | ✅ User-observable |
|---|---|
| "The auth module is well-structured" | "POST /auth/login with valid creds returns 200 and a JWT; with invalid creds returns 401" |
| "Tests pass" | "`npm run test:e2e tests/checkout.spec.ts` exits 0" |
| "Refactor complete" | "`npm test` exits 0 AND `git diff --stat HEAD~1` shows only files under `src/payments/`" |
| "DDD layers in place" | "Importing from `src/domain` does not transitively pull in `src/infrastructure` (verified by `npx dependency-cruiser src/domain --validate`)" |
| "Code is clean" | (this is not a task — it's a code-review item; remove it from PLAN.md) |
| "Bug is fixed" | "Reproducer in `tests/regression/bug-1234.test.ts` exits 0; manual reproduction steps in the issue no longer trigger the error" |
| "Feature is implemented" | (decompose — what does the user *do*?) |

## Categories of valid acceptance tests

Pick whichever fits the task. Combine when one alone is fakeable.

### 1. Command-level

A shell command that exits 0 iff the task is done.

```yaml
acceptance: "npm run typecheck && npm run test:unit -- auth/"
```

Cheap, deterministic, easy for the loop to parse. Default to this when possible.

### 2. HTTP / API behavior

```yaml
acceptance: |
  Start server, then:
    curl -X POST localhost:3000/api/rules -d '{"name":"r1"}' returns 201 with a body { id: <number> }
    curl localhost:3000/api/rules returns a JSON array containing the created rule
    curl -X DELETE localhost:3000/api/rules/<id> returns 204
    curl localhost:3000/api/rules returns an array NOT containing the deleted rule
```

Use when the task is "expose this thing to clients".

### 3. Browser / UI

```yaml
acceptance: |
  `npm run test:e2e tests/rules.spec.ts` exits 0
  AND screenshot `tmp/autopilot/rules-after-create.png` shows a row with name "test-rule-1"
```

Use for UI tasks. **Always** include a screenshot — Playwright passing doesn't prove the screen looks right (claudefa.st's lesson).

### 4. Data-level

```yaml
acceptance: |
  After running the migration:
    psql -c "SELECT COUNT(*) FROM users WHERE email_verified_at IS NULL" returns 0
    psql -c "\d users" includes column email_verified_at timestamp NOT NULL
```

Use when the change is "the database now looks like this".

### 5. File-system diff

```yaml
acceptance: |
  `git diff --name-only HEAD~1` lists ONLY:
    src/legacy/auth/*  (deleted)
    src/v2/auth/*     (any change)
  AND `rg "legacy/auth" src/` returns no matches
```

Use for refactors and migrations where the proof is structural.

### 6. Manual one-line check (last resort)

```yaml
acceptance: "User can open localhost:3000/rules, click 'Add', enter a name, click Save, see the new row."
```

Use only when no automated check is feasible. The loop will emit `NEEDS_HUMAN` to ask you to verify — this turns the task from autonomous to semi-autonomous, which is sometimes the honest answer.

## Patterns that look concrete but are not

These slip past most reviewers. Reject them.

- **"Tests pass"** without naming which tests. The agent will add a passing test of its choosing and call it done.
- **"X is implemented"** with no exit criterion. Implemented how? Where's the proof?
- **"Following the existing pattern"** — the agent will choose a "pattern" that costs the least effort.
- **"Code review approved"** — only valid if a human actually reviews; otherwise the agent will self-review.
- **"No errors in console"** — silent failures don't produce console errors.
- **"Performance is acceptable"** — what number? Under what load?

## Decomposition rule of thumb

If a task's acceptance criterion is hard to write concretely, the task is **too big or too vague**. Split it.

A reliable split heuristic: list the smallest user-visible change in behavior. If you can't name one, you're being asked to refactor for refactor's sake, and that doesn't belong in an autonomous run — do it interactively.

## Verify the check itself is runnable

A user-observable criterion is only useful if the *check* runs in the environment the loop has. Before approving an acceptance criterion in PLAN.md, confirm:

| Check kind | Precondition to verify |
|---|---|
| `git diff <file>` | `<file>` is git-tracked (not in `.gitignore`, not untracked). On untracked files diff is empty → vacuous pass. |
| `npm test` / `pytest` | The test runner installs cleanly in this environment, dependencies cached. |
| `curl localhost:<port>` | The server can be started by the loop (or a sidecar) within reasonable iteration time. |
| Browser screenshot | A headless browser (Playwright/Chromium) is installed. |
| `psql` / DB query | DB connection works, credentials are available, fixtures load. |
| WSL commands from Windows host | Use `wsl.exe -- bash << 'EOF' … EOF` heredoc form, not `-c '…'`. See [halt-conditions](halt-conditions.md) §"WSL quoting". |
| `git diff --stat HEAD~1` | At least one commit exists since session start (and `auto_commit: yes`, otherwise nothing's committed). |

RUN.md Step 2's "Probe acceptance preconditions" enforces this. If a precondition fails, the iteration emits `<status>NEEDS_HUMAN</status>` rather than running a check that can't actually verify anything.

Acceptance criteria that *look* concrete but can't be verified in your environment are worse than vague ones — they pass silently when nothing happened.
