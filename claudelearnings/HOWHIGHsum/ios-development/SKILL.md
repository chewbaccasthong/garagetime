---
name: ios-development
description: Use when building or modifying any native SwiftUI iOS app. Load when the user opens a `.swift` file, mentions SwiftUI, MVVM, `@Observable`, ViewModels, services, persistence, the iOS folder structure, naming conventions, or testing. Skip if the project is React Native / Flutter / KMP / web — this is native-iOS-only.
applies_to: any new SwiftUI iOS app. Adapt iOS version targets per current Apple defaults.
---

# iOS development patterns

Durable preferences for any new SwiftUI iOS app.

## Targets & language
- Minimum deployment **iOS 17.0** so `@Observable` and modern Swift concurrency are available without backport.
- Swift, native, no cross-platform frameworks (no React Native, Flutter, KMP).
- iPhone-first; only add iPad support when a feature actually needs it. Including iPad in `TARGETED_DEVICE_FAMILY` makes iPad screenshots required and forces iPad-side QA.

## SwiftUI vs UIKit
- **SwiftUI-only** by default. Drop to UIKit only when there's no SwiftUI equivalent: `UIApplicationDelegateAdaptor` for APNs callbacks, `UIActivityViewController` wrappers, `SignInWithAppleButton` (which is fine).
- SwiftUI Charts for any plotting. Don't pull in a charting SPM dep.
- Honor system color scheme (`.preferredColorScheme(nil)`); design for both light and dark.

## Architecture
- **MVVM with `@Observable`** ViewModels. ViewModels are `@MainActor final class`. State the UI reads is `private(set) var`; only the VM mutates it.
- Top-level app state held as `@State` on the `App` struct, built in `init()`. Inject downward through views — no global singletons except `UIApplicationDelegateAdaptor`-bound routers and prepared engines (audio/haptics).
- **Services behind protocols.** Every service touching the system (sensors, storage, network, keychain, push, IAP, attest) gets a `protocol Foo` plus a real impl and a fake/in-memory impl. ViewModels and tests depend on the protocol.
- One singleton-ish `Backend` holder for the network stack (auth + client + sync + push + store) built once in `App.init`. Provide a `Backend.preview()` factory wiring local-only / in-memory variants for previews and tests.
- **Best-effort sync.** Local writes first (UI never blocks on the server), then enqueue a server push. Persist the queue (`Documents/sync-queue.json`) so a kill-9 doesn't lose state. Retry transient errors, drop permanent ones.
- **Server is the source of truth for any economy / scoring.** Mirror constants between Swift and the server with parity tests both sides. Client never credits currency itself — JWS / receipts go to the server, server writes the canonical answer.
- `weak var` back-references between ViewModels (e.g. `weak var sync` on a profile VM) so tests can exercise local logic without instantiating the whole graph.

## Folder structure
```
<App>/
  <App>App.swift              — entry point, builds graph, picks Real/Mock
  Theme/Theme.swift           — color tokens (asset-driven), Spacing, Radius, Font
  Audio/                      — AVAudioEngine wrappers, no bundled files
  Haptics/                    — CoreHaptics patterns
  Utilities/                  — formatters, small helpers
  Models/                     — Codable value types
  Services/                   — protocols + real + mock impls
  ViewModels/                 — @Observable @MainActor classes
  Views/                      — SwiftUI; subfolders per screen with 3+ files
  Backend/                    — auth, client, sync, push, store, keychain, attest
  <Feature>/                  — feature-scoped folders when a feature spans
                                models + storage + VM that don't fit elsewhere
  Assets.xcassets/            — colorsets per theme token, AppIcon
<App>Tests/                   — Swift Testing, one *Tests.swift per VM/service
```
Sibling `supabase/` (or other backend) directory at repo root, NOT inside the Xcode project.

## Naming conventions
- Service protocols: gerund or `-ing`/`-able` suffix — `SensorManaging`, `ThrowStoring`, `KeychainStoring`, `BackendClient`.
- Real impls: descriptive concrete prefix — `RealSensorManager`, `JSONFileThrowStorage`, `RemoteBackendClient`.
- Test/fallback impls: `Mock…`, `InMemory…`, `LocalOnly…`, `Fake…`.
- ViewModels: `<Noun>ViewModel`. Views: `<Noun>View`; full-screen takeovers can use `<Noun>Screen`.
- Codable models: singular nouns (`Throw`, `SensorSample`).
- Theme tokens: `Color` / `Font` extensions namespaced by an app prefix (e.g. `tossAccent`, `tossDisplayHuge`) — never reference raw color literals from view code.
- UserDefaults keys: dotted strings under an app prefix (`"<app>.detection.threshold"`), declared as `private static let` on the owning type.

## Persistence
- Prefer **one JSON file per record** under `Documents/<Feature>/` for log-shaped data — simpler than CoreData/SwiftData, trivially exportable, easy to inspect via Files.app.
- Expose Documents to Files.app + Mac Finder via Info.plist `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` whenever raw export is useful.
- **Tolerant `Codable` decoders** with explicit `schemaVersion` field so old records migrate forward in place. Don't orphan old schemas.
- Storage actor or single-writer queue when concurrent writes are possible. Always provide an `InMemory…` impl behind the same protocol for tests.
- Keychain via `KeychainStoring` protocol — real Security-framework impl + `InMemoryKeychain` for tests. Never store auth tokens in UserDefaults.

## Testing
- **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`) over XCTest for new code.
- `@MainActor @Suite(.serialized)` for any suite that touches a `@MainActor` VM.
- Test the VM/service against the protocol fakes, not the real impl. Wire test fixtures via constructor injection.
- `URLProtocol` fakes for network-touching code rather than mocking the client interface — exercises the real serialization path.
- Don't add a test target that requires the simulator booting — keep tests pure-logic.

## Networking
- **Hand-rolled URLSession** beats vendor SDKs (Supabase, Firebase, Amplify) for v1 unless you specifically need Realtime/websockets/etc. that the SDK provides. Trade-off accepted: zero SPM churn, fully testable, ~few hundred lines.
- Typed errors with an `isRetriable` flag drive the sync queue's drop-vs-retry decision.
- Polling (10–30s while a screen is visible) beats websockets for leaderboards / lists. Add Realtime only when there's a real reason.

## Concurrency gotchas
- **System callbacks may land on non-main dispatch queues** even when you ask for `OperationQueue.main`. Symptom: `MainActor.assumeIsolated` traps inside `_swift_task_checkIsolatedSwift` on a TCC queue (CoreMotion / CoreLocation are common offenders). Fix: hop via `Task { @MainActor [weak self] in … }` instead of asserting isolation.
- Apple reviewers run on iPad even for iPhone-only apps — strict-concurrency traps that don't fire on your dev iPhone may crash on iPad and cause a rejection.

## Audio + haptics
- **Synthesized audio** via `AVAudioEngine` + `AVAudioSourceNode` writing PCM buffers. Avoid bundling WAV/MP3 unless a sound has to be a real sample — keeps the binary tiny and lets sounds be parametric.
- **CoreHaptics** patterns over `UINotificationFeedbackGenerator` for anything more nuanced than success/warning/error. Build a small `HapticEngine` singleton with named patterns.
- Prepare both engines once at app launch (`SoundEngine.shared.prepare()`).

## Theming
- Asset-catalog `Color Set`s with light + dark variants for every semantic role. View code only references `Color("ThemeAccent")` via a typed extension.
- `Spacing` and `Radius` enums of static `CGFloat` constants — no raw `.padding(16)` in views.
- `Font` extension with display/title/body/mono/caption variants. Use `.system(...).width(.condensed)` for display weights instead of bundling a custom font unless you really need one.

## Always vs never
- **Always** prefer editing existing files; injection over singletons; protocols over concrete types in service slots.
- **Never** force-unwrap in production code. Tests can `try!` / `!` freely.
- **Never** add an SPM dependency without a written justification — every dep adds project.pbxproj churn and Package.resolved conflicts.
- **Never** check in `.p8` keys, `service_role` keys, App Store Connect API keys, or anything in `~/.<app>-*` dotfiles. Anon keys and bundle IDs are fine.
- **Never** `git add -A` blindly — raw data exports / crash logs often land in repo root.
