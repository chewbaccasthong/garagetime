---
name: agents-and-delegation
description: Use when deciding whether to delegate to a subagent vs do work directly. Covers built-in agents (Plan, Explore, general-purpose) and project-specialized agents. Triggers: "use the X agent", "delegate to subagent", any decision about parallelization, when context budget is tight, or when designing a new specialized agent file.
---

# Agents and delegation

When to delegate, what kind of agent to use, and how to write prompts that don't waste a fresh agent's context.

## Built-in agents

**Plan**
- Designs implementation plans before coding.
- Use when: task spans 3+ files, has architectural trade-offs, or you'd want a second pair of eyes on the approach before writing.
- Returns a structured plan, not code.
- Don't use for: single-file edits, well-understood refactors, mechanical translations.

**Explore**
- Read-only search agent.
- Use for: "where is X defined", "which files reference Y", pattern lookups across many files.
- Cheap and parallelizable — fire 3 in parallel for "find all X / Y / Z" simultaneously.
- Specify search breadth: `quick` (single lookup), `medium` (moderate), `very thorough` (multi-location naming-convention search).
- Don't use for: code review, design-doc audits, cross-file consistency checks (it reads excerpts, not whole files).

**general-purpose**
- Catchall for multi-step research / orchestration when no specialized agent fits.
- Use when: task spans multiple steps + multiple files, no specialized agent matches.
- Don't use as a default — prefer Read/Bash directly when the target is known.

## Specialized agents (per-project)

Live at `~/.claude/agents/<name>.md` (global) or `.claude/agents/<name>.md` (project). Auto-discovered by the harness.

Frontmatter format:
```
---
name: <kebab-case>
description: Use when <load trigger — concrete phrases>
tools: filesystem
---

You are an expert in <domain>. When invoked, follow these conventions:

1. <numbered convention>
2. <…>

When proposing <artifact>, include <quality bar>.
```

Examples that worked on a shipped iOS+Supabase app:
- `swift-frontend-builder` — SwiftUI views/ViewModels conventions, MVVM rules, theme token usage, animation defaults
- `supabase-architect` — Postgres schemas, RLS-first thinking, edge function patterns, migration discipline
- `monetization-architect` — StoreKit 2, IAP, App Store Connect product config, server-validated credit
- `cheat-defender` — physics validation, rate limiting, anomaly detection, DeviceCheck integration
- `data-scientist` — Python sensor analysis, findings document format, algorithm validation

Body should be ~10–30 numbered conventions, not a tutorial. The agent already knows the tech — it needs the project's opinions.

## When NOT to delegate

- Target file path is already known → use Read directly.
- Single grep with a known string → use Bash with `grep`.
- Task fits in <2 minutes of focused work → just do it.
- You'd need to re-explain the same context the agent doesn't have → either bring the agent up to speed once and reuse via SendMessage, or just do it.

## Delegate-vs-do decision tree

```
Is the target known? ────────────────► Read / Bash directly
        │ no
        ▼
Is it a code lookup or pattern search? ──► Explore (cheap, parallel)
        │ no
        ▼
Does a specialized agent's domain match? ─► That specialized agent
        │ no
        ▼
Is it multi-step research / orchestration? ─► general-purpose
        │ no
        ▼
Is it implementation planning? ──────────► Plan
        │ no
        ▼
Just do it.
```

## Subagent prompt rules

Agents start with **zero context** from the calling conversation. Brief them like a colleague who walked into the room cold.

- **State the goal, not the steps.** "Find X and report" beats "do A, then B, then C" — prescribed steps become dead weight when the premise is wrong.
- **Self-contained:** include file paths, line numbers, what specifically to change. The agent can't see your scrollback.
- **Cap response length** when relevant — "report in under 200 words" keeps tool results from flooding context.
- **Lookups vs investigations:** for lookups, hand over the exact command. For investigations, hand over the question.
- **Trust but verify:** an agent's summary describes what it intended to do, not necessarily what it did. After write/edit work, check the actual changes.

## Parallelization

When delegating multiple **independent** tasks:
- Fire all Agent calls in a **single message** with multiple tool blocks. They run concurrently.
- Don't sequentially call agents for tasks that don't depend on each other — that's wall-clock waste.

When agents have downstream dependencies:
- Fire them sequentially, with the second agent's prompt informed by the first's output.

`run_in_background: true`:
- Use when you have other foreground work to do meanwhile.
- The harness notifies you on completion — don't poll, don't sleep.
- Foreground (default) when you need the result before proceeding.

## Anti-patterns

- **Duplicating work:** if you delegate research to an agent, don't also search yourself in parallel. Pick one path.
- **Vague terse prompts:** "fix the bug" produces shallow generic output. Brief properly.
- **Asking the agent to "synthesize my findings":** that's offloading understanding. The synthesis is your job — write prompts proving you understood ("change function X at line Y to do Z").
- **Spawning agents for trivial work:** the cost is non-zero. <2 min of work? Just do it.
- **Forgetting to mention writing-vs-research:** clearly tell the agent whether you expect code changes or just a report. They can't read the user's intent from your conversation.

## Continuing an agent across turns

- `Agent(...)` always starts a **fresh** agent with no memory of prior runs. Prompt must be fully self-contained.
- `SendMessage` to an agent's ID/name resumes it with full context. Use this when the same agent should keep going on the same task.
- Check the running-agents list before spawning — duplicate agents on the same task waste tokens.
