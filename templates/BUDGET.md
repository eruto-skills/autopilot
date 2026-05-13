# BUDGET

> Hard ceilings. The loop checks these at Step 0 of every iteration and exits `BLOCKED` if any is exceeded.

## Caps

```yaml
max_iterations: 25            # total loops before forced stop
max_cost_usd: 50              # rough ceiling; track manually or via /cost
max_wallclock_h: 8            # wall-clock since first iteration started_at
max_consecutive_failures: 3   # per-task; the loop body enforces this, not the wrapper
min_progress_iterations: 5    # if this many iterations pass with zero passes:true flips, emit BLOCKED
```

## Policy flags

```yaml
auto_commit: no   # captured during interview (SKILL.md step 3).
                  # `yes` → loop runs `git commit` on every task that flips passes:true (RUN.md step 5a)
                  # `no`  → loop only updates PLAN.md and prints "ready to commit: T<id>"; user commits manually
                  # Default `no` aligns with global Claude Code policy "only commit when requested"
```

## Counters (loop updates these)

```yaml
iterations_used: 0
started_at: <ISO 8601 set by first iteration>
last_pass_at: <ISO 8601 — last time a task flipped passes:true>
estimated_cost_usd: 0         # update on each iteration if /cost is available
```

> **Schema discipline**: this file is hand-edited YAML by the loop. Keep keys exactly as written; if you rename or add a top-level key, also update RUN.md Step 0.3 to read it. The skill does not currently ship a parser/validator — schema drift is a known footgun (Friction #12 in the dogfood log).

## Halt notifications

When the loop hits any of:

- `<status>BLOCKED</status>`
- `<status>NEEDS_HUMAN</status>`
- `max_cost_usd` exceeded
- `max_wallclock_h` exceeded

…the wrapper should notify the user. Configure here:

```yaml
notify:
  slack_webhook: ""           # leave empty to skip
  email: ""                   # leave empty to skip
  desktop: true               # macOS osascript / Windows BurntToast / Linux notify-send
```

If all notify channels are empty, the run will still halt cleanly — just silently. You will see the status when you next open the session.

## Cost sanity check

At Sonnet 4.6 rates, a continuous autonomous run burns roughly **$10/hour** under heavy tool use. At the default caps above (8h × ~$10/h ≈ $80) you will likely hit `max_cost_usd: 50` before `max_wallclock_h: 8`. That is intentional — the cost cap is the real backstop.

If you set caps much higher than the defaults, also set up a sandbox (devcontainer / Docker / cco wrapper) — runaway loops with elevated permissions are the way people accidentally rm-rf or leak credentials.
