# autopilot

A Claude Code skill that scaffolds long-running, hands-off sessions without burning money on the wrong problem.

## What it does

`/autopilot <task>` walks you through:

1. **Plan** — define the task as a list of subtasks, each with a **user-observable acceptance criterion**
2. **Budget** — set hard caps on iterations, cost, and wall-clock
3. **Mode** — pick interactive (`/loop`), local cron, or cloud (`/schedule` Routines)
4. **Hand-off** — print the exact command to start the loop

The loop itself is built on top of Anthropic's official `/ralph-loop` plugin and the bundled `/loop` skill. autopilot adds three regimens those alone don't enforce:

- The agent re-reads the plan + accumulated lessons at the top of every iteration (deterministic stack — context never bloats)
- Three consecutive failures on a task halts the run (truth-bias defense)
- Ambiguity surfaces as `<status>NEEDS_HUMAN</status>` instead of a guess

## Install

Clone the repo somewhere stable, then run the installer for your OS. It links the skill into `~/.claude/skills/autopilot/` so Claude Code discovers it. Idempotent — safe to re-run.

```bash
git clone https://github.com/eruto-skills/autopilot.git
cd autopilot
```

```powershell
# Windows (no admin / dev-mode needed — uses a directory Junction)
pwsh -File scripts/install.ps1
```

```bash
# macOS / Linux
bash scripts/install.sh
```

Then in any Claude Code session: `/autopilot <task description>`.

### If you can't run the script

The installer is just one command. Manual equivalent:

```powershell
# Windows
New-Item -ItemType Junction `
  -Path  "$env:USERPROFILE\.claude\skills\autopilot" `
  -Target (Resolve-Path .)
```

```bash
# macOS / Linux
ln -s "$(pwd)" ~/.claude/skills/autopilot
```

## File layout

```
autopilot/
├── SKILL.md                       # the skill definition (workflow Claude follows)
├── README.md                      # this file
├── templates/
│   ├── PLAN.md                    # task list with user-observable acceptance tests
│   ├── RUN.md                     # loop body — fed to Claude every iteration
│   ├── LESSONS.md                 # cross-iteration memory (Reflexion-style)
│   └── BUDGET.md                  # caps + halt conditions
└── references/
    ├── completion-criteria.md     # the single highest-leverage page — read first
    ├── halt-conditions.md         # exit statuses + the truth-bias problem
    ├── modes.md                   # interactive / local-cron / cloud comparison
    └── prior-art.md               # which pattern came from where
```

## When to use vs not use

**Use** when: multi-step task, you'll walk away, mistakes are expensive to undo, you want a postmortem.

**Don't use** when: single repetitive poll (use `/loop` directly), already-clear one-shot prompt (use `/ralph-loop` directly), or you'll be at the keyboard anyway.

## The non-obvious pieces

If you only read three things in this repo:

1. [`references/completion-criteria.md`](references/completion-criteria.md) — why "tests pass" is not an acceptance criterion
2. [`references/halt-conditions.md`](references/halt-conditions.md) — why 3 failures is the rule, not 5 or 10
3. [`templates/RUN.md`](templates/RUN.md) — the actual loop body; everything else exists to make this small

## Prior art

This skill composes ~20 patterns from Anthropic's official docs, the English Ralph-loop community, the Japanese 自走 community, and agentic-loop research. Full attribution in [`references/prior-art.md`](references/prior-art.md).

## License

Inherits the parent repo's license.

## Codex / Claude Code installation

For an existing clone, run `bash scripts/install.sh --host codex` on macOS/Linux,
or `./scripts/install.ps1 -HostName codex` in Windows PowerShell.
The installer keeps Claude as its default target and preserves existing directories.

This package supports both Codex and Claude Code. The plugin entry point is
`skills/autopilot/SKILL.md`; the root `SKILL.md` remains the standalone source.

For Codex, add the public `eruto-skills` marketplace in the plugin UI using
`https://github.com/eruto-skills/marketplace`, then install `autopilot`.
To install as a standalone user skill instead:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/eruto-skills/autopilot.git ~/.agents/skills/autopilot
```

On Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE/.agents/skills" | Out-Null
git clone https://github.com/eruto-skills/autopilot.git "$env:USERPROFILE/.agents/skills/autopilot"
```

In Codex, select the installed skill by name or invoke `$autopilot` with a task.
In Claude Code:

```text
/plugin marketplace add eruto-skills/marketplace
/plugin install autopilot@eruto-skills
```

The instructions use the tools available in the current host. Scripts are resolved
from the actual skill directory, rather than a fixed author path. Additional browser,
Python, or format-specific dependencies are described in `SKILL.md` and the references;
installing the plugin alone does not install those external programs.

## Maintaining the plugin package

Edit the root `SKILL.md` and its supporting resources, then run:

```bash
node scripts/package-plugin.mjs
node scripts/package-plugin.mjs --check
```

Commit the generated `skills/` files with the source changes. CI checks that both
layouts match, including the Claude manifest. Do not edit generated files directly.
