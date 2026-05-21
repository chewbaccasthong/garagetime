---
name: supabase-backend
description: Use when designing or modifying a Supabase backend — Postgres schemas, RLS policies, edge functions in Deno, auth flows including anonymous + Sign In with Apple, materialized views for leaderboards, sync engine patterns, or server-side economy mirroring. Triggers: files under `supabase/migrations/` or `supabase/functions/`, mentions of RLS, `service_role`, anon key, edge function, pg_cron, materialized view, anonymous sign-in, App Store Server Notifications V2 webhook.
applies_to: any app where Supabase is the backend. Patterns adapt to Firebase / Convex / PlanetScale by analogy.
---

# Supabase backend patterns

Hard-won lessons from shipping a Supabase-backed iOS app end-to-end.

## Auth model: anonymous-first, never gate

- Every user gets a Supabase UUID on first launch. **No sign-in UI as a gate.** First action works without seeing an account screen.
- Sign In with Apple (or other providers) is offered as an **upgrade path** in Settings → Account for cross-device account recovery. Most users never touch it.
- Why: zero friction onboarding, plus SIWA depends on the **paid Apple Developer Program** which not all dev/test setups have — making it a gate breaks dev environments.
- Anonymous sign-ins must be toggled ON in Dashboard → Authentication → Sign In/Providers → "Allow anonymous sign-ins". Default is OFF; symptom when missed is `anonymous_provider_disabled` on every launch.

## Keys: anon ships, service_role NEVER does

- Client only ever holds the **anon key**. Safe to ship in `BackendConfig.swift` or equivalent — it's gated by RLS.
- The **`service_role` key is master and bypasses RLS.** Lives only in edge function platform env (Dashboard → Project Settings → Edge Functions → Secrets). Never paste into chat, client code, or commits.
- If service_role leaks (chat history, accidental commit), rotate via Dashboard → Project Settings → API → Reset service role key.

## RLS from migration #1

- Enable RLS on every table the moment it's created. Policies in the same migration that creates the table (or the very next).
- Pattern: own-only by default → `using (auth.uid() = user_id)`. Public-read tables (profiles, leaderboards) are explicit `for select using (true)`.
- Column-level grants when you want public-read but own-only-write: `grant update (nickname, equipped_*) on profiles to authenticated`.
- All privileged writes (currency credit, friend mutations, IAP redeem, account deletion) go through edge functions running as service_role — clients can't INSERT into ledger / purchase tables directly.

## Migrations are append-only

- Never edit a deployed migration in place. Write a new `0004_…sql`.
- If you re-seat the project, applying 0001…N in order must reproduce production. Edit-in-place breaks that contract silently.
- Apply by pasting into Dashboard → SQL Editor → Run, in numeric order. CI deploy via `supabase db push` works once you trust the workflow.

## Edge functions in TypeScript/Deno

- One folder per function under `supabase/functions/<name>/index.ts`.
- Shared modules under `supabase/functions/_shared/` for: economy constants, validation helpers, REST client wrapper, push sender, etc.
- **Mirror business constants** between Swift and TS in `_shared/`. Tests on both sides catch drift; if drift happens, "I earned 24 locally but server credited 23" user reports follow.
- Test helper: `supabase/functions/_tests/run_all.sh` invoking `deno test --allow-all` for each `_shared/` module.
- CORS headers + auth-bearer extraction belong in a tiny shared helper, not copy-pasted per function.
- **Never INSERT into `profiles` from edge functions** — the `on_auth_user_created` trigger creates the row on `auth.users` insert. Inserting from an edge fn races the trigger.

## Materialized views for leaderboards

- Mat views + a `refresh_*()` SECURITY DEFINER function called by `pg_cron`.
- `REFRESH MATERIALIZED VIEW CONCURRENTLY` requires a **unique index** on the view (e.g. `leaderboard_alltime_user_idx UNIQUE on (user_id)`). Don't drop these.
- Trigger an immediate refresh after a successful throw upload too — cron is cheap insurance, not the only path.
- Schedule via `pg_cron`:
  ```
  select cron.schedule('refresh-leaderboards','*/5 * * * *',
    $$ select public.refresh_leaderboards(); $$);
  ```

## Triggers do row plumbing

- `on_auth_user_created` fires on `auth.users` insert and creates the profile row with a generated nickname.
- Throw-insert trigger auto-resolves any pending challenge whose target the new throw beats — keeps the resolution atomic with the insert, edge function just queries for resolved challenges and fans out push.
- Triggers + RLS are how the client stays dumb. Resist moving this logic to the client.

## Sync engine pattern

- Local writes first; UI never blocks on the server.
- Enqueue server pushes (throws / achievements / challenges / purchases / profile-edits) in an in-memory queue persisted to `Documents/sync-queue.json` (so kill-9 doesn't lose state).
- Each queue entry has a `queuedAt` timestamp; transient errors retry, permanent errors (e.g. 401 unauthorized after token death) drop.
- Surface `pendingCount` + `lastError` + `lastSuccessAt` for a diagnostics view.
- Field name gotcha: in Swift, `throws` is a keyword — call the queue field `throwUploads` not `throws`. The persisted JSON has `"throwUploads": [...]` accordingly.

## Networking: hand-rolled URLSession over supabase-swift

- Skip the `supabase-swift` SPM package for v1 unless you need Realtime websockets specifically.
- A `RemoteBackendClient` (~440 lines) talks to PostgREST + Auth + Edge Functions over URLSession.
- Trade-offs you accept:
  - Lose: Realtime websockets, supabase-swift's auto-refresh helpers.
  - Gain: zero SPM dependencies (no project.pbxproj edits, no Package.resolved conflicts), trivially testable with URL-protocol fakes, full visibility into the wire format.
- Token refresh: roll your own `AuthService.refresh()` calling `/auth/v1/token?grant_type=refresh_token`.

## App Store Server Notifications V2 webhook

- Set the webhook URL in App Store Connect → App → App Information → App Store Server Notifications.
- Webhook target on Supabase side: **don't verify JWT bearer** — the request body itself is a signed JWS. Set `verify_jwt = false` in `supabase/config.toml` for that function.
- Inside the function, decode the JWS, check the `notificationType` (`REFUND`, `REVOKE`, `CONSUMPTION_REQUEST`, etc.), and revoke the corresponding ledger entry idempotently.

## Required setup checklist (per project)

- [ ] Project created at supabase.com; URL + anon key copied to client config.
- [ ] Anonymous sign-ins toggled ON.
- [ ] `service_role` key set as edge function secret only.
- [ ] All migrations 0001…N pasted into SQL Editor in order.
- [ ] All edge functions deployed: `supabase functions deploy <name> --project-ref <ref>` for each.
- [ ] `pg_cron` extension enabled (Database → Extensions) + leaderboard refresh schedule.
- [ ] If using SIWA: paid Apple Developer team selected in Xcode, Services ID + Key ID + JWT client secret pasted into Auth → Apple. **JWT expires every 180 days** — calendar reminder.
- [ ] If using push: APNs `.p8` (separate key from SIWA) + Team ID + Bundle ID set as edge function secrets.
- [ ] Privacy nutrition labels on App Store Connect declare what Supabase touches.
