---
name: apns-push-notifications
description: Use when implementing iOS push notifications via APNs. Triggers: `UNUserNotificationCenter`, `registerForRemoteNotifications`, `didRegisterForRemoteNotificationsWithDeviceToken`, mentions of APNs, `.p8` key, ES256 JWT, device token, `aps` payload, push deeplinks, sandbox vs production push, or any push design discussion.
---

# APNs push notifications

Hand-rolled APNs HTTP/2 with ES256 JWT signing — works without an SDK, works on any backend.

## Server-side: hand-rolled APNs HTTP/2

- Sign an **ES256 JWT** with Apple's `.p8` private key as the bearer token.
- POST to `https://api.push.apple.com/3/device/<token>` (production) or `https://api.sandbox.push.apple.com/3/device/<token>` (sandbox).
- HTTP/2 only — Apple deprecated HTTP/1.x. Deno's `fetch` handles HTTP/2 transparently; Node needs `http2` module.
- JWT claims: `iss = team_id`, `iat = now`. Sign with the `.p8` ECDSA key, kid = the APNs key ID. Cache the JWT for ~50 minutes (Apple recommends ≤60).
- Required headers: `apns-topic: <bundle.id>`, `apns-push-type: alert | background | voip | …`, `authorization: bearer <jwt>`.

A working `_shared/push.ts` is ~120 lines:
- `signAPNsJWT(teamId, keyId, p8Pem)` — uses Web Crypto SubtleCrypto for ES256.
- `sendPush(deviceToken, payload, env)` — does the POST, returns a status enum.
- **Silently no-ops if env secrets are missing**, so dev setups without APNs configured still work — social/notification features just don't deliver.

## .p8 key registration

- developer.apple.com → Keys → register a NEW key with **"Apple Push Notifications service (APNs)"** capability.
- **Use a separate key from the Sign In with Apple key.** Each .p8 maps 1:1 to a capability; mixing them is a footgun if one ever needs revocation.
- Download the .p8 ONCE — Apple won't let you re-download. Store as a server secret (env var, KMS, or platform secret manager).
- Note the **Key ID** (10 chars, e.g. `ABC123XYZ9`) and your **Team ID** (10 chars, top-right of developer.apple.com).

## Required server secrets

For Supabase as backend, set in Dashboard → Project Settings → Edge Functions → Secrets:
- `APNS_TEAM_ID` — your Apple Developer Team ID.
- `APNS_KEY_ID` — the APNs key's 10-char ID.
- `APNS_PRIVATE_KEY` — the contents of the `.p8` file (`-----BEGIN PRIVATE KEY-----…`). Multi-line; Supabase handles the linebreaks.
- `APNS_BUNDLE_ID` — `com.<you>.<app>` (the apns-topic header).
- `APNS_USE_SANDBOX` — `true` while testing in Xcode debug, `false` for TestFlight + App Store.

## Sandbox vs production hosts

- **TestFlight builds use the production APNs host**, NOT sandbox. Common confusion.
- **Xcode debug builds running on a real device use sandbox**.
- The device token bytes are the same; the destination host is what differs.
- Easiest: keep two flag values (`APNS_USE_SANDBOX_DEBUG` and `APNS_USE_SANDBOX_TESTFLIGHT`) or just set `APNS_USE_SANDBOX=true` in dev and flip to `false` before TestFlight.

## Client-side: token registration flow

```
1. PushService.requestPermissionAndRegister()
   → UNUserNotificationCenter.current().requestAuthorization(...)

2. UIApplication.shared.registerForRemoteNotifications()

3. AppDelegate (UIApplicationDelegateAdaptor):
   func application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
     → AppRouter.shared.didReceiveDeviceToken(tokenHex)

4. AppRouter (singleton mediator) → PushService.didReceiveDeviceToken
   → BackendClient.registerPushToken(tokenHex)

5. Server: upsert into push_tokens table keyed by user_id + bundle.
```

Why the `AppRouter` singleton: `AppDelegate` has no SwiftUI scope, so it can't reach into the `@State`-held `Backend` directly. `AppRouter.shared` mediates.

## Tap routing (deeplink-style)

```
1. AppDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:)
   → reads userInfo, forwards to AppRouter.handlePushUserInfo(userInfo)

2. AppRouter:
   - Reads kind / id from userInfo
   - setRoute(.friendChallenge(challengeId)) — published @Observable property

3. ContentView observes the route:
   .onChange(of: router.pendingRoute) { route in
     switch route { case .friendChallenge(let id): showSheet(...) }
   }
```

Apple's deeplink URL scheme registration in Info.plist (`CFBundleURLTypes`) is **only needed for external links** (iMessage / safari `tossapp://...`). Push routing works without it — userInfo dict bypasses URL handling entirely.

## Required iOS setup

- Paid Apple Developer Program (free tier can't enable Push).
- Push capability in entitlements (Signing & Capabilities → + → Push Notifications).
- Background Modes capability + "Remote notifications" if you handle background pushes.
- Info.plist: nothing required by default. Permission UI handled by `requestAuthorization`.

## Push payload

```json
{
  "aps": {
    "alert": { "title": "...", "body": "..." },
    "sound": "default",
    "badge": 1
  },
  "kind": "friend_challenge",
  "challenge_id": "<uuid>"
}
```

- `aps` keys are Apple-defined. Anything else at the top level becomes user-defined data passed to `userInfo`.
- For **silent / background pushes**: omit `alert`/`sound`/`badge`, set `"content-available": 1` inside `aps`, set `apns-push-type: background` header. Throttled by Apple — don't rely on for time-critical work.

## Common gotchas

- **No push delivered in TestFlight but works in dev** → flipping the sandbox/production host. TestFlight is production.
- **400 "BadDeviceToken"** → device token is for the wrong env (sandbox token sent to production host or vice versa). Re-register on the correct env.
- **403 "InvalidProviderToken"** → JWT signing key mismatch or expired (rotate every <60 min).
- **410 "Unregistered"** → user uninstalled or revoked notifications. Drop the token from the server table; don't retry.
- **No tap callback fires** → `UNUserNotificationCenter.current().delegate` not set in `application(_:didFinishLaunchingWithOptions:)`. Set it from `AppDelegate.application(_:willFinishLaunchingWithOptions:)`.
