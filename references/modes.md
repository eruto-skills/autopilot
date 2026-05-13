# Modes — How to actually run the loop

`autopilot` doesn't run the loop itself. It scaffolds the artifacts, then hands off to one of four runners. Pick by use case.

## Decision matrix

| Use case | Mode | Why |
|---|---|---|
| You're at the keyboard, want hands-off but supervised | **interactive** (`/loop`) | Cheapest setup, you can interrupt |
| You want to walk away, laptop stays awake | **local-cron** | Full control, more setup, sandbox required |
| You want to walk away, laptop closes | **cloud** (`/schedule` Routines) | No 4-walls hassle; min 1h interval |
| Single-prompt while-loop, no plan | **ralph-loop plugin** | Use directly without this skill |

## Mode 1 — Interactive (`/loop`)

The simplest mode. You stay in the session; the loop fires the RUN.md prompt repeatedly with `ScheduleWakeup`-style self-pacing or a fixed interval.

```
/loop @.claude/autopilot/RUN.md
```

If you want a fixed interval (e.g., 5 min between iterations to let async builds settle):

```
/loop 5m @.claude/autopilot/RUN.md
```

> **Path separators on Windows**: Claude Code accepts forward slashes in `@`-references on Windows too, so `@.claude/autopilot/RUN.md` works identically on PowerShell, cmd, Git Bash, and WSL. There is no need to use backslashes here. (Backslashes inside `@`-paths confuse the `@`-reference parser anyway.)

**Strengths**: zero setup, you see every output, you can `<status>BLOCKED</status>` → `Esc` → fix → resume.

**Weaknesses**: bound to your session; closing the laptop kills it. Cost is borne against your interactive plan/credits.

## Mode 2 — Cloud (`/schedule` Routines)

Anthropic's managed cron, runs on their infra.

```
/schedule "Autopilot loop" --prompt "$(cat .claude/autopilot/RUN.md)" --interval 1h --max-iterations 25
```

**Strengths**: laptop can be closed; no permission prompts at runtime; Anthropic handles the sandbox.

**Weaknesses**: minimum 1h interval (not great for fast-feedback tasks); cost lands on the Routines plan; can't observe progress without re-opening the session.

For overnight runs of slow tasks (e.g., "explore N approaches to the build issue, report tomorrow"), this is the right answer. For fast tight loops, use interactive or local-cron.

## Mode 3 — Local cron (the 4-walls recipe)

This is the most powerful and the most dangerous. Use only inside a sandbox (devcontainer / Docker / cco wrapper). Source for the 4-walls breakdown: [atani / Pepabo](https://zenn.dev/pepabo/articles/claude-code-cron-autonomous-ui-walls).

```bash
# Wall 0 — keep the machine awake (macOS)
pmset -c sleep 0
caffeinate -dimsu -t 28800 &   # 8 hours

# Wall 1 — bypass the "Bypass Permissions" startup screen
# claude -p reads stdin; the startup screen needs an arrow-down + Enter.
# Use expect (or pty + script).

# Wall 2 — bypass "Trust this folder"
# Same expect script; send Enter on the trust dialog.

# Wall 3 — MCP permissions
# Pre-define in ~/.claude/settings.json:
#   permissions.allow: ["Read", "Grep", "Glob", ...]
#   permissions.deny:  ["Write to /etc/**", "Bash rm -rf*", ...]
#   permissions.ask:   [] (empty for unattended)

# Wall 4 — exclude dangerous repos
# Wrapper script checks $PWD against EXCLUDE_REPOS before invoking claude.

# Then the actual run:
claude -p --dangerously-skip-permissions \
  --output-format stream-json \
  --max-turns 50 \
  < .claude/autopilot/RUN.md \
  | tee -a .claude/autopilot/run.log \
  | jq -r 'select(.type=="result") | .result' \
  | grep -E '<status>(DONE|BLOCKED|NEEDS_HUMAN)</status>' && exit 0
```

Wrap this in a cron job that fires every 5–15 minutes. The `grep` gates termination — when the loop emits DONE/BLOCKED/NEEDS_HUMAN, cron sees a 0 exit and the next firing's wrapper sees the status file and stops.

**Strengths**: full control; works offline; can drive multiple repos in parallel.

**Weaknesses**: setup is fiddly; `--dangerously-skip-permissions` is a footgun without a sandbox; you own the safety story (Anthropic's auto-mode classifier helps but has 17% FNR per their [own writeup](https://www.anthropic.com/engineering/claude-code-auto-mode)).

## Mode 4 — `/ralph-loop` plugin directly

If your task is genuinely "one prompt, run until DONE", skip `autopilot` and use the plugin Anthropic ships:

```
/ralph-loop "Your task here" --max-iterations 25 --completion-promise "DONE"
```

This is what `autopilot` is built on top of conceptually. The reason to use `autopilot` over raw `/ralph-loop` is: plan + acceptance criteria + lessons + halt conditions. If you don't need those, `/ralph-loop` alone is simpler.

## Picking the right mode (cheat sheet)

- Single prompt, single task, no state? → `/ralph-loop`
- At keyboard, multi-step plan? → **interactive**
- Walking away, fast feedback needed? → **local-cron** (with sandbox)
- Walking away, slow OK, no laptop? → **cloud**

When in doubt, start interactive. Promote to cloud/local-cron only after you've seen the run survive at least one `NEEDS_HUMAN` and resume cleanly.

## Notification when the loop halts

All three modes should notify when status hits a non-`CONTINUE` value. Configure in `BUDGET.md`:

- **interactive**: the session naturally surfaces it
- **cloud**: configure email/Slack via the Routines UI
- **local-cron**: wrapper script reads BUDGET.md `notify` block and fires Slack webhook / desktop notification / email

Silent halts are a footgun. You'll discover the run died at noon when you check at 8pm. Set up at least one notify channel before kicking off any unattended run.
