# LESSONS

> Cross-iteration memory. Read at the top of every loop iteration; rules here apply for the rest of the run.
> Each entry is dated, 1–3 lines, framed as a **durable rule** — not a diary entry.

## Who writes here (contract)

- **The running loop** appends one entry when an iteration produces a durable, non-obvious learning (RUN.md step 5a item 4). This is the primary author.
- **The scaffolding step** (SKILL.md step 5) may write at most ONE seed entry, labelled `scaffold`, recording the user's initial intent or known constraints. This is rare — usually PLAN.md "Open questions" is the right home for scaffold-time concerns.
- **Humans** should NOT manually edit existing LESSONS entries between iterations — that breaks the loop's "deterministic stack" assumption. To override a lesson, append a new entry that supersedes the old one (and the loop will see the newer one win on conflict by date).

## Format

```
## 2026-MM-DD
- Rule: <imperative sentence — what to do or not do>
- Why: <one sentence — the failure or surprise that produced this rule>
- How to apply: <when does this kick in>
```

## Examples (delete before the run; here as illustration)

```
## 2026-01-15
- Rule: Run `npm run db:reset` before any test that depends on auth fixtures.
- Why: Acceptance tests for T03 failed three times in a row because a prior session left a stale admin user.
- How to apply: Any task whose acceptance touches the users table.

## 2026-01-15
- Rule: Do not import from `@/lib/legacy/*` — those modules are scheduled for removal.
- Why: T04 added a dependency on legacy/auth that the next refactor task had to undo.
- How to apply: When picking a module to import, prefer `@/lib/v2/*`; if only legacy exists, surface as an Open question, not an import.
```

## Entries

<!-- new entries appended below by the loop -->
