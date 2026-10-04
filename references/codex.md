# Codex execution

This mode executes in the current Codex session; it does not install a scheduler or promise work after the session ends.

1. Use the user's request as the task input. Reuse known goal, observable acceptance checks, budget limits, commit authorization, and output location. Ask only for missing choices needed to run safely; existing authorization stays valid.
2. Resolve the project root and inspect changes in the task's scope. Preserve other work. Use .agents/autopilot/ for new runs; an existing .claude/autopilot/ run can be resumed at that same path.
3. Generate PLAN.md, RUN.md, LESSONS.md, and BUDGET.md from the bundled templates. Rewrite artifact paths in RUN.md to the chosen run directory and resolve its reference links to installed skill files. Read the host's AGENTS.md and project instructions. Show the concrete plan for any approval still required by the user's request.
4. Execute RUN.md in this session when the user has authorized execution. Select one task per iteration, reread the plan and lessons, implement it, and run its observable acceptance checks. Do not call Claude slash commands or invent scheduling tools.
5. Update task notes, iteration count, elapsed time, and lessons after every iteration. Cost must be marked unavailable unless actual usage data is provided. If a required monetary ceiling cannot be enforced, stop and ask for a measurable alternative; never claim an estimated figure is a hard cap.
6. Stop on completion, the user stopping, a budget/iteration ceiling, ambiguity, or three consecutive failures on the same task. Record DONE, CONTINUE, NEEDS_HUMAN, or BLOCKED in the run notes. These are artifact statuses, not instructions to override the host's own goal API rules.
7. Summarize shipped tasks, checks, used iterations, remaining questions, and the exact run directory. Resume by reading those four files and continuing the next pending task. Only a separately available and authorized scheduling capability can arrange a later session; without one, provide a resume prompt and state that no job was reserved.

Use available Codex tools for file access, shell commands, questions, and any authorized delegation. Subagents remain optional for research/review, and implementation stays sequential. Promote durable lessons to AGENTS.md or the project's shared instruction file only with the applicable authorization.
