# Prior Art — Who this skill borrows from

`autopilot` does not invent. It composes patterns from four bodies of work — Anthropic's official guidance, the English-speaking community around Ralph loops, the Japanese-language community around 自走 patterns, and the agentic-loop research literature. This page credits each pattern to its source so you can read the originals and form your own opinion.

## The composition

| Pattern in autopilot | Source |
|---|---|
| While-loop body / "deterministic stack allocation" | Geoffrey Huntley — [ghuntley.com/ralph](https://ghuntley.com/ralph) |
| `<status>DONE</status>` + `--completion-promise` | Anthropic — [/ralph-loop plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) |
| PRD-as-state-machine (passes:true/false) | Pasquale Pillitteri — [Ralph Wiggum Coding Loop](https://pasqualepillitteri.it/en/news/192/ralph-wiggum-claude-code-loop-bash-coding-agent) |
| User-observable acceptance criteria (NG/OK distinction) | jujunjun110 — [3エージェント分業ループ](https://note.com/jujunjun110/n/n0903bad8b2f2) |
| Screenshot-verification two-pass for UI | claudefa.st — [Ralph Wiggum technique](https://claudefa.st/blog/guide/mechanics/ralph-wiggum-technique) |
| Cross-iteration LESSONS.md (Reflexion-style) | Shinn et al. — [Reflexion (arXiv:2303.11366)](https://arxiv.org/abs/2303.11366) |
| Plan-and-Solve upfront | Wang et al. — [Plan-and-Solve Prompting](https://github.com/AGI-Edgerunners/Plan-and-Solve-Prompting) |
| Orchestrator + workers architecture | Anthropic — [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents) |
| Subagent fan-out cap for builds (backpressure) | Geoffrey Huntley — same source |
| 3-consecutive-failure halt (truth-bias defense) | yhei_hei — [X post 1938552898742313305](https://x.com/yhei_hei/status/1938552898742313305) |
| "Ambiguous → ask, do not guess" default | Findy — [CLAUDE.md暴走防止運用](https://tech.findy.co.jp/entry/2025/12/06/070000) |
| "ai 暴走 は 100% 人間側のプロンプトが曖昧" framing | SIOS techlab — [Claude調教3テクニック](https://tech-lab.sios.jp/archives/48160) |
| Compounding Engineering (promote LESSONS → CLAUDE.md) | ot12 — [Boris Cherny作者15並列流](https://qiita.com/ot12/items/66e7c07c459e3bb7082d) |
| Plan Mode → Auto-accept One-Shot pattern | ot12 — same |
| 4-walls cron handling (caffeinate / expect / MCP / repo exclude) | atani / Pepabo — [cron autonomous UI walls](https://zenn.dev/pepabo/articles/claude-code-cron-autonomous-ui-walls) |
| Stop hook keep-alive (`{"decision":"block"}`) | Anthropic docs + syu-m-5151 — [Hooks解説](https://syu-m-5151.hatenablog.com/entry/2025/07/14/105812) |
| Auto-mode classifier numbers (17% FNR) | Anthropic — [Claude Code Auto Mode](https://www.anthropic.com/engineering/claude-code-auto-mode) |
| tmux + "let it cook" + CLAUDE.md + test oracle | Anthropic — [Long-running Claude](https://www.anthropic.com/research/long-running-Claude) |
| Worktree parallelism for speculative work | Cursor 2.0 changelog + jujunjun110's "ハーネスエンジニアリング" Phase B1–B5 |
| Watchdog / Supervisor (independent reviewer) | guyskk — [claude-code-supervisor](https://github.com/guyskk/claude-code-supervisor) |
| Cost figure ($10/hr Sonnet 24h burn) | claudefa.st economics post |

## Patterns considered and rejected

These appeared in the survey but were intentionally **not** baked into the templates:

| Pattern | Why excluded |
|---|---|
| Tree-of-Thoughts over file edits | Side effects don't backtrack cleanly; ToT belongs in read-only research phases, not the main loop |
| Self-Refine (one LLM, three roles, same conversation) | Conflated roles produce sycophantic critique; Evaluator-Optimizer (two LLMs) is cleaner — we leave that to subagents instead of baking into the loop |
| AutoGPT-style "infinite task queue, self-generate next" | The whole reason autopilot has PLAN.md is to refuse this. Self-generated next-task is how you get $300 bills overnight |
| `--dangerously-skip-permissions` by default | Users must opt-in per mode (only `local-cron`); we never recommend it without a sandbox |
| Voice notification (ニケちゃん AivisSpeech style) | Cute but adds a dependency most users won't need; the BUDGET.md `notify` block leaves it as an option |
| `tmux send-keys` between paneled Claudes (kazuph style) | Powerful but adds a control-plane the user has to babysit; orchestrator+workers via Anthropic's Agent tool achieves the same without a tmux dependency |
| "Maximum subagent fan-out, no caps" (@plastic_gear) | Burns rate-limit cleanly but defeats the cost-cap design; users who want this can call `/ralph-loop` directly |

## The 29:26 Anthropic video

The viral [@1osabori tweet](https://x.com/1osabori/status/2050458903947952519) referenced an Anthropic-official video that "reveals the 24-hour trick". That video is:

- **Title**: "Prompting for Agents | Code w/ Claude"
- **Speakers**: Hannah Moran, Jeremy Hadfield
- **URL**: https://www.youtube.com/watch?v=XSZP9GhhuAc
- **Companion blog**: [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)

The "trick" is not a single secret — it's the composite Anthropic publishes across [Long-running Claude](https://www.anthropic.com/research/long-running-Claude), the [scheduled-tasks docs](https://code.claude.com/docs/en/scheduled-tasks), the [`/ralph-loop` plugin](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum), and the building-effective-agents essay. autopilot's job is to make that composite trivially reusable.

## How this skill differs from the references

Most existing tools and writeups give you one piece — the loop body, or the plan format, or the halt condition. `autopilot` enforces the **combination**:

1. You cannot start a run without a user-observable acceptance criterion (most sources mention this; few enforce it)
2. You cannot retry past 3 failures (yhei_hei rule, baked into RUN.md)
3. You always re-read PLAN.md + LESSONS.md (Huntley's deterministic stack)
4. You always emit a status (the cron/loop wrapper relies on it)
5. You always have a notify channel for halts (silent halts kill trust in the system)

Take any of these out and the run becomes a "$10/hr lottery". Keeping all five is the whole pitch.
