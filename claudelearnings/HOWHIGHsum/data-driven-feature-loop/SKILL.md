---
name: data-driven-feature-loop
description: Use when shipping an app whose features depend on a measurement / signal-processing pipeline that needs ongoing tuning from real-world data. Triggers: sensor apps, ML-in-the-loop apps, classifier tuning, anything where the user collects field data and an analysis layer feeds tweaks back. Mentions of "round N", "FINDINGS", "HANDOFF", "analysis side", "tune the algorithm".
applies_to: apps with a measurable outcome where v1 numbers will be wrong and need real-world iteration. Skip for pure CRUD apps.
---

# Data-driven feature loop

A two-repo iteration pattern that lets a measurement / signal-processing app converge to ground truth across multiple field-data rounds.

## Why a loop

For any app where v1 ships with a guess at thresholds / weights / formulas:
- The first 5 captures will reveal something obvious that nukes the v1 model.
- Without a structured loop, you tune in-place, lose the "why we changed X", and the algorithm becomes folklore.
- With a structured loop, every parameter has a paper trail back to a specific finding from a specific round.

## The two-repo pattern

```
~/Projects/<platform>/<app>/         ← App repo (ships data captures + algorithm)
~/Projects/python/<app>-analysis/    ← Analysis repo (Python notebooks, plots, models)
```

- **App repo** writes one JSON-per-record under `Documents/<Feature>/`. Surfaces them via Files.app + share sheet.
- **Analysis repo** ingests those JSONs, runs analyses, writes structured findings + implementation handoffs **back into the app repo's root**.
- Two parallel Claude Code sessions — one in each repo. Each has its own CLAUDE.md context.

The findings + handoffs live in the **app repo** because that's where future-you debugs from. The analysis repo is where they're written; the app repo is where they're read.

## Per-round artifact contract

Two files at the app repo root per round:

### `FINDINGS-analysis-round-N.md`

What the analysis layer learned this round.

Sections:
- **Capture summary**: how many captures, what conditions, what was the test scenario
- **What works**: confirmed correct behaviors
- **What's broken**: bugs surfaced by the data, with evidence (charts / numbers / specific capture IDs)
- **Open questions**: things this round couldn't settle; what data would settle them
- **Recommended changes**: numbered, each with rationale

### `HANDOFF-implementation-round-N.md`

Concrete change list for the implementation layer.

Sections per change:
- **What to change**: file + function + the literal change
- **Why**: one-line rationale (often a quote from FINDINGS)
- **Acceptance criteria**: how the implementation knows it landed (test passes, value falls in range, etc.)
- **Risk**: what could regress; what to verify still works

A change without an acceptance criterion is not a handoff — it's a wish.

## Round cadence

- Round 1: just enough captures to validate v1 (~3–5).
- Round 2–N: deliberate data-collection sessions targeting the previous round's open questions. Aim for 10–30 captures per round.
- Never tune the algorithm without the round paperwork. If you find yourself "just tweaking," stop and write the FINDINGS first — even a 200-word one.

## Capture infrastructure

- **One JSON per record** under `Documents/<Feature>/<record>-<timestamp>-<uuid>.json`.
- Schema includes raw sensor traces, derived features, algorithm output, and `analysisVersion` so old captures don't get reinterpreted by new algorithm versions silently.
- Tolerant `Codable` decoder so v1 schema captures still load when v3 schema is current. Migrate forward in place; don't orphan old data.
- Expose Documents to Files.app: Info.plist `UIFileSharingEnabled = YES` + `LSSupportsOpeningDocumentsInPlace = YES`.
- Settings → Export All → `UIActivityViewController` for the iOS share sheet.

## Decision protocol when findings disagree with intuition

User says "I threw it 3 meters" but algorithm says 1.2m. Two possibilities:
1. Algorithm is wrong → tune.
2. User's perception is wrong → settle with ground truth (video against a ruler, hard-floor drops with measured heights, etc.).

**Don't tune until the disagreement is resolved.** Capture more data targeting the disagreement specifically — Round N's #1 task becomes "settle the apex-perception question." Tuning blind to which side is wrong propagates the error in either direction.

This is the most expensive lesson in the loop. Defaulting to "the algorithm is wrong" because the user said so is how a measurement app drifts further from ground truth over months.

## When to use this loop

- Sensor apps (IMU, GPS, audio) with derived metrics
- ML-in-the-loop apps where the model improves from field data
- Anything with thresholds, weights, or formulas tuned by experiment
- Anything where shipping a v1 number, then refining over months, is the lifecycle

## When NOT to use it

- Pure CRUD apps with no measurable outcome — overkill
- Apps where the algorithm is locked at v1 and won't improve — overkill
- Solo-prototype phase, < 5 captures total — the round paperwork is friction at this scale

## Tools that worked

- Python in the analysis repo: pandas, numpy, matplotlib, scipy.signal. Notebooks for exploration; scripts for reproducible plots.
- iOS-side capture is just `JSONEncoder` writing to `Documents/<Feature>/`. No extra deps.
- Findings are markdown — no special tooling. Future-you reads them in plain text or rendered.

## Subagent fit

For projects with this loop, a `data-scientist` subagent with the analysis-side conventions baked in (Python style, FINDINGS document format, plot conventions) makes the analysis-side iteration cheap.

The implementation side benefits less from a specialized agent — the changes are usually targeted enough that a normal session works.
