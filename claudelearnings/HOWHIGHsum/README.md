# claudeblocks — portable skill brain

A folder of focused skill files extracted from completed projects. Each skill is a self-contained `SKILL.md` with YAML frontmatter that tells a future Claude Code session when to load it.

This is meant to be **implanted into the next build**. Symlink it into a new project, and Claude inherits everything we learned without rediscovering it.

## How to use this in a new project

1. Symlink (or copy) into the new project root:
   ```
   ln -s ~/Projects/ios/TOSS/claudeblocks claudeblocks
   ```
2. Add to the new project's `CLAUDE.md`:
   ```
   ## Portable skills
   See `claudeblocks/`. Each subfolder has a SKILL.md with frontmatter
   describing when to load it. Read `claudeblocks/README.md` first for
   the index.
   ```
3. The `description` field on each SKILL is the load trigger — Claude reads it, picks the matching ones, applies the contents.

## Skill file format

```
---
name: <kebab-case-id>
description: Use when … Load whenever the user is … or says "…"
applies_to: <scope hint, optional>
---

# <Title>

<concrete checklists, gotchas, and patterns. project-agnostic.>
```

Concrete trigger phrases > vague scope. The description should make the load decision obvious.

## Growth contract

This folder grows after every shipped project:

1. After ship, walk back through what was hard, what was repeated, what was novel.
2. For each recurring pattern, write or update a SKILL.md.
3. **Strip project-specific names** — no app name, bundle ID, project ref, currency name. If a sentence wouldn't make sense in a different app, generalize it or delete it.
4. Keep concrete checklists. Generic prose decays — checklists ship.
5. When two skills overlap, merge them or split cleanly. Don't duplicate.

## Index

| Skill | When it loads |
|---|---|
| [`ios-development/`](ios-development/SKILL.md) | Any SwiftUI iOS app — architecture, naming, folder structure, testing |
| [`app-store-submission/`](app-store-submission/SKILL.md) | Shipping to the App Store — paperwork, screenshots, rejection patterns |
| [`supabase-backend/`](supabase-backend/SKILL.md) | Supabase as backend — RLS, edge functions, sync patterns |
| [`storekit-2-iap/`](storekit-2-iap/SKILL.md) | In-app purchases — server-validated credit, restore, webhooks |
| [`apns-push-notifications/`](apns-push-notifications/SKILL.md) | Push notifications via APNs HTTP/2 |
| [`project-memory-system/`](project-memory-system/SKILL.md) | CLAUDE.md / STATE.md / round-N paperwork pattern |
| [`agents-and-delegation/`](agents-and-delegation/SKILL.md) | When to use Plan / Explore / specialized subagents |
| [`data-driven-feature-loop/`](data-driven-feature-loop/SKILL.md) | Two-repo pattern — app + analysis side, round-N artifacts |
| [`toolchain/`](toolchain/SKILL.md) | Concrete build / test / verify commands |

## What this folder is NOT

- Not a substitute for project-level `CLAUDE.md` / `STATE.md` (those stay per-project).
- Not generic Apple / Swift documentation — only portable lessons learned the hard way.
- Not a tutorial. Future-Claude already knows the basics; this is the deltas worth preserving.
