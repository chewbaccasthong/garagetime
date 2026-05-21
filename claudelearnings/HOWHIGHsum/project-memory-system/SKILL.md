---
name: project-memory-system
description: Use when starting a new project, onboarding a fresh Claude session into an existing project, deciding what goes in CLAUDE.md vs STATE.md, or writing handoff/findings paperwork. Triggers: "set up CLAUDE.md", "session handoff", "what should go in memory", "FINDINGS", "HANDOFF", or starting work on any multi-week project that will span sessions.
---

# Project memory system

A four-layer memory model that survived a multi-month, multi-session shipped project.

## The four layers

| Layer | Where | Lifetime | Purpose |
|---|---|---|---|
| **CLAUDE.md** | repo root, checked in | project lifetime | Identity, stack, conventions, decisions log |
| **STATE.md** | repo root, checked in | session-to-session | Brain dump: gotchas, in-flight work, weird-but-intentional patterns |
| **FINDINGS / HANDOFF round-N** | repo root, checked in | per measurement round | Data-driven feature loop artifacts (only for measurement-heavy apps) |
| **Auto-memory** | `~/.claude/projects/<encoded-path>/memory/` | cross-project | User preferences, feedback, references |

CLAUDE.md is always loaded. STATE.md is read after CLAUDE.md by convention (a one-line pointer in CLAUDE.md tells future sessions to do this). Round paperwork is loaded only for sessions touching the relevant subsystem. Auto-memory is the harness's job.

## CLAUDE.md — what goes in

**Identity (top):**
- App name + tagline + bundle ID
- One-paragraph "what it is"
- Tech stack list

**Targets:**
- Primary device + OS version + minimum deployment

**Current stage:**
- One-line phase summary; ship status; test counts

**Build stages:** numbered, with ✅ for completed.

**What's working right now:** the algorithmic / functional capabilities, with concrete numbers (test counts, calibration values, etc.).

**What's next:** the next 1–4 things, ordered by leverage.

**Project structure:** an ASCII tree of the repo with one-line annotations per important file.

**Conventions:** the durable rules — SwiftUI-only, MVVM, no force unwrapping, etc.

**Decisions log:** dated one-liners for every non-obvious choice.
```
- 2026-04-23: Free Apple Developer tier; SwiftUI over UIKit; iOS 17+ minimum
  for @Observable.
- 2026-04-29: Theme is asset-catalog-driven (10 colorsets) so dark mode swaps
  for free; no hardcoded colors anywhere outside `Theme.swift`.
- 2026-05-03 (Phase 3): Hand-rolled URLSession over supabase-swift SDK —
  zero SPM dependencies, fully testable, easier to reason about.
```

**Build / test commands:** the exact `xcodebuild` / `supabase` / etc. invocations.

**Sister project pointer:** if there's a paired analysis repo or backend repo, link it.

CLAUDE.md should fit in ~200 lines. Past that, split into STATE.md.

## STATE.md — what goes in

A `## How this project works` section explaining the meta — e.g. "two repos in a loop, app ships JSON, analysis writes findings back."

A `## What's at the top of mind right now` section — last session's brain.

A `## Phase N architecture` section — directory tree of what's actually deployed for the active phase.

A `## How a <core flow> flows now` section — narrative of the request lifecycle for the most important feature path.

A `## What you can test right now` section — exact reproduction steps.

**`## Gotchas you will absolutely hit`** — the most valuable section. Each gotcha is:
- 1-line title
- 2–4 lines of context
- The fix or how to recognize the symptom

Example:
```
### Anonymous sign-in must be enabled in Supabase
Dashboard → Authentication → Sign In/Providers → "Allow anonymous sign-ins"
must be toggled ON. Without this, every app launch fails with
`anonymous_provider_disabled` and nothing syncs.
```

**`## Architectural decisions worth knowing`** — the why behind non-obvious choices, framed as "Why no X" / "Why anonymous-first auth" / "Why server-side mirror." Each ~6 lines.

**`## Things that look weird but are intentional`** — code patterns that would make a reasonable reviewer suggest a refactor, with a one-paragraph defense. Saves future-you from undoing your own past judgment.

**`## Things to NOT do unless explicitly asked`** — the destructive corner cases (don't `git add -A`, don't add the SDK we deliberately rolled our own around, don't INSERT into tables that triggers handle, etc.).

**`## State of the world right now`** — branch, commit count, test counts, deploy status.

**`## Remaining setup the USER must do`** — ordered checklist of human-only steps (toggle this in dashboard, paste this JWT, etc.).

Update STATE.md at the end of any session that meaningfully changed the brain dump.

## FINDINGS / HANDOFF round-N

For data-driven projects only — see `data-driven-feature-loop/SKILL.md`.

- `FINDINGS-analysis-round-N.md` — what the analysis side learned this round, surfaced bugs, recommended changes.
- `HANDOFF-implementation-round-N.md` — concrete change list for the implementation side, ordered, with acceptance criteria per item.

Both files persist forever — they're the audit trail of "why does the algorithm have this constant" months later.

## Auto-memory at `~/.claude/projects/.../memory/`

The harness manages this. Don't write project facts here (they belong in CLAUDE.md / STATE.md). Do write:
- **user** memories — the user's role, expertise, what frame to use when explaining things
- **feedback** memories — corrections AND validated approaches the user accepted without pushback
- **project** memories — who's doing what, by when (with absolute dates, never "Thursday")
- **reference** memories — pointers to external systems (Linear project IDs, Slack channels, dashboards)

Each memory is a single file with frontmatter + body, indexed in `MEMORY.md`.

## How CLAUDE.md and STATE.md compose

A pattern that worked:
- CLAUDE.md ends with `## Sister project` pointing at the analysis repo OR `## Read STATE.md next` if STATE exists.
- STATE.md opens with `Read after CLAUDE.md for orientation, then this for the gotchas and reasoning that isn't obvious from the code.`
- A future session naturally reads top-down: CLAUDE → STATE → relevant round paperwork → relevant claudeblocks.

## When to spin up STATE.md vs leave it out

- Solo project, < 1 week, single subsystem → CLAUDE.md alone is fine.
- Anything spanning 2+ weeks, 2+ sessions, or 2+ subsystems → start STATE.md early. The brain-dump section is the load-bearing one.
- After every "phase complete" milestone, add a brain-dump section to STATE.md before moving on. The post-phase context evaporates fast.

## Anti-patterns to avoid

- **Putting in-flight task details in CLAUDE.md.** That's STATE.md territory. Mixing them means CLAUDE.md churns on every session, defeating the "stable identity" purpose.
- **Decisions log entries without dates.** Future-you can't tell which constraint is current.
- **Decisions log entries without rationale.** "Switched to X" without "because Y" gets undone.
- **Updating CLAUDE.md mid-feature** instead of in a dedicated commit. Mixes feature context with documentation noise.
- **Documenting code structure in CLAUDE.md that's already obvious from `tree`.** Reserve the prose for the why.
