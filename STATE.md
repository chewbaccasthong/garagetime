# STATE.md — Garage Time

Read after `CLAUDE.md` for orientation, then this for the gotchas and reasoning that isn't obvious from the code.

## How this project works

Single-developer iOS app, single-user product (no multi-tenant backend in v1). All persistence is SwiftData → CloudKit (Apple-owned). No external backend. No edge functions. No webhooks. RevenueCat is the only third-party considered for v1 (and even that is wrapped behind a protocol so the StoreKit 2 implementation stands alone today).

Project layout uses `xcodegen` so the `.xcodeproj` is regenerated from `project.yml` on demand. This keeps the repo clean of pbxproj merge conflicts and makes adding files a directory-add, not an Xcode dialog.

## What's at the top of mind right now

Phase 1 (Foundation) is the active surface. Everything in this commit is meant to **compile and launch** the app to a TabView with empty screens, with all models persisting through SwiftData + CloudKit. Subsequent stages add real UX to each tab.

## Phase 1 architecture (what's deployed)

```
GarageTime/
  GarageTimeApp.swift          — entry, builds Backend, wires SwiftData
  Theme/Theme.swift            — colors, spacing, radius, font, motion
  Components/                  — GSCard, GSButton, GSTextField, GSStatusPill, GSStatBlock, GSEmptyState, GSSectionHeader, GSLineItemRow, GSConfirmDialog
  Models/                      — all SwiftData @Model entities + supporting enums
  Services/                    — NHTSAService, OCRService, NotificationService, PDFExportService, PartsFinderService, QuoteNumberService, SignatureService, StoreService, ReminderEngine
  ViewModels/                  — per-screen @Observable VMs
  Views/                       — per-tab folders, each with at least a screen, a row, and a detail
```

`Backend` is a small holder that builds and exposes one instance of each service. Built once in `GarageTimeApp.init()` and injected into the environment.

## How a "create vehicle" flows now

1. User taps **+ Add Vehicle** in `GarageView`.
2. `VehicleAddEditView` opens with `VehicleEditorViewModel`.
3. User picks owner-type. If `.customer`, a customer picker shows below the toggle.
4. User taps **Scan VIN** → `VINScanView` (DataScannerViewController wrapped) returns a `String`.
5. VM calls `NHTSAService.decode(vin:)`. The service caches results in-memory keyed by VIN and falls back to `nil` on no-network.
6. VM autofills year/make/model/trim/etc., user reviews, taps **Save**.
7. VM creates a `Vehicle` via `modelContext.insert(...)`, calls `try modelContext.save()`.
8. CloudKit sync happens out-of-band; UI doesn't block.
9. `GarageView` re-renders from `@Query` automatically.

## What you can test right now

After Stage 1:
```bash
xcodegen generate
open GarageTime.xcodeproj
```
Set the team to your developer account, hit ⌘+R. The app should launch into a 5-tab TabView. Each tab shows an empty state. Tap **+ Add Vehicle** in the Garage tab → a vehicle form opens. Save → the vehicle persists across launches.

## Gotchas you will absolutely hit

### CloudKit + SwiftData requires defaults on every property
Without defaults or `Optional` wrappers, the first sync silently fails and the model never appears on a second device. Symptom: works locally, never round-trips. Fix: every `@Model` property is either `Optional` or has `= defaultValue`. No `.unique`, no required relationships.

### CloudKit container ID must match the entitlement EXACTLY
Entitlement uses `iCloud.com.henrygawelek.garagetime`. The `ModelConfiguration` in `GarageTimeApp` passes the same string. If you rename the bundle ID without updating both, sync fails silently — Apple's logs are quiet about it.

### Money is `Double` on disk, `Decimal` in math
Stored as `Double` for CloudKit + Codable convenience. Anywhere we add/multiply, we convert to `Decimal` (`Decimal(double)`), do the math, convert back via `NSDecimalNumber(decimal:).doubleValue`. Rounding to currency uses `Money.round`.

### DataScannerViewController availability
`DataScannerViewController.isSupported` and `.isAvailable` must BOTH be true. iPhone XS+ for hardware; iOS 16+ for SDK. Fall back to manual entry on simulators / older devices.

### Strict-concurrency: never `assumeIsolated`
Strict concurrency is `complete`. System callbacks from Vision / Notifications / BackgroundTasks can land on non-main queues. Always hop via `Task { @MainActor [weak self] in … }` to update VM state — never `MainActor.assumeIsolated`.

### `Color("token")` requires the asset to exist
Theme tokens read from `Assets.xcassets`. If you add a token in `Theme.swift` you MUST add the corresponding colorset. The compiler does not catch missing colorsets — they render as the system default at runtime.

### `@Query` filters can't use protocol-typed predicates
SwiftData's `#Predicate` macro must reference concrete `KeyPath`s. Cannot abstract through a protocol. Keep query VMs concrete per model type.

### Reminders need `BGTaskScheduler` registration on app launch
`BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.henrygawelek.garagetime.refresh", …)` MUST happen in `GarageTimeApp.init()`, before any view loads. Symptom of forgetting: silent — your task never fires.

### Notifications require permission asked at the right moment
First-launch permission ask = rejected by user 70%+ of the time. Ask on **first reminder created**, in-context, after explaining what they'll get. Never on launch.

### Apple reviewers may run on iPad
Even iPhone-only apps get launch-tested on iPad in iPhone-compatibility mode. Test before submission. Watch for layout that breaks on iPad's wider iPhone-canvas (the simulated bezel changes safe-area).

## Architectural decisions worth knowing

### Why unified `Vehicle` with `ownerType`
Two-table split (`PersonalVehicle` / `CustomerVehicle`) doubles every service-history query and forces UNION logic in reports. A single `Vehicle` with `ownerType: .personal | .customer` keeps queries simple at the cost of a single-field-difference between rows. The single-field difference is genuine; the doubled query surface would be artificial.

### Why SwiftData + CloudKit over Supabase/Firebase
Single-user product. No leaderboards, no social. CloudKit is free, doesn't need a backend, works on a free Apple Developer account (the iCloud entitlement does need paid program for App Store).

### Why protocols for services we only have one impl of
Lets tests run without the simulator. `NHTSAService` protocol + `RealNHTSAService` + `InMemoryNHTSAService`. The fakes are 30-line files; the testability is worth it.

### Why `xcodegen` over checked-in `.xcodeproj`
Multi-month projects accumulate pbxproj diffs that are unreviewable and merge-conflicty. `project.yml` is reviewable. `.xcodeproj` regenerates in <1 second.

### Why PDF rendering with PDFKit + Core Graphics, not WKWebView
WKWebView PDF dumps look great but require an HTML template, JavaScript layout pass, and Web inspector debugging on iOS. PDFKit + CG context gives pixel-precise control with no async render step. Customer-ready PDFs need pixel precision (logos, signatures, totals alignment).

## Things that look weird but are intentional

- **Every service has an `InMemory…` impl** even when there's no obvious use today. The fakes exist to let test suites and SwiftUI previews construct a `Backend` without hitting the network or filesystem.
- **`Money` is its own type with no operators.** No `+`/`*` on the `Money` struct itself. Math goes through `Decimal`; `Money` is for formatting + storage. This prevents accidental `Double` precision bugs in totals.
- **`GSButton` doesn't take a label closure.** It takes `title: String` + `icon: String?`. Limits the visual variants we can create and keeps quote PDFs / paywall buttons / list actions consistent.
- **`Vehicle.photoData` is `Data?`** (not `UIImage`). Persisted via `@Attribute(.externalStorage)` so CloudKit syncs the file rather than the asset table row. Decoded into `UIImage` at view-render time only.
- **No `@StateObject`.** With `@Observable`, all VMs are `@State` on the owning view. `@StateObject` is the pre-iOS-17 pattern.

## Things to NOT do unless explicitly asked

- Don't `git add -A`. Run `git status` first; OCR receipts, scratch JSON, `.p8` keys, and crash logs land in repo root.
- Don't commit `GarageTime.xcodeproj/`. Regenerate from `project.yml`.
- Don't add an SPM dependency without writing why in `CLAUDE.md` → Decisions log.
- Don't store secrets in source. RevenueCat keys, App Store Connect API keys go in `~/.wrenchbook-*` (gitignored) and are read at run time.
- Don't change `Catalog` product IDs after shipping IAP. App Store Connect bindings are permanent.
- Don't drop `TARGETED_DEVICE_FAMILY` to `1,2` (iPad) without committing to iPad screenshots + iPad QA.

## State of the world right now

- Branch: `main`
- Stages 1–14 complete (Foundation through Paywall). Stage 15 (TestFlight) blocked on user enrolling in Apple Developer Program.
- Tests: 25 tests across 6 suites, all passing.
  - `MoneyTests` — currency math precision (5)
  - `QuoteTotalsTests` — labor + parts + tax + discount + non-taxable lines (4)
  - `ReminderUrgencyTests` — overdue / due-soon / progress (4)
  - `OCRTests` — receipt total + vendor extraction (4)
  - `PaywallGateTests` — free / pro / shop tier gating (4)
  - `VINDecodeTests` — inferred type + powertrain from NHTSA result (4)
- App launches on iPhone 17 Pro simulator (iOS 26.5). CloudKit falls back to local-only when no iCloud account; in-memory if local fails.
- Settings → "Load sample data" seeds 2 customers, 4 vehicles, 4 service records, 3 reminders, 1 draft quote with line items.
- Deploy status: not yet on TestFlight.

## How to test it RIGHT NOW

```bash
cd "/Users/henryg/Projects/ios/WRENCH BOOK"
xcodegen generate
open GarageTime.xcodeproj                            # Xcode → set Team → ⌘+R
# or, headless on the booted sim:
xcodebuild -project GarageTime.xcodeproj -scheme GarageTime \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install booted "$(xcodebuild -project GarageTime.xcodeproj \
  -scheme GarageTime -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR ' | head -1 \
  | awk -F' = ' '{print $2}')/GarageTime.app"
xcrun simctl launch booted com.henrygawelek.garagetime
```

In the app: **More → Settings → "Load sample data"** to populate. Browse Garage, tap a customer vehicle, open the draft quote, sign it, export the PDF.

## App Store readiness checklist (v1.0)

Status of every gate Apple checks at submission. Confirmed items have a ✓; user-action items have a ☐.

### Apple Developer Program
- ☐ Enroll in paid Developer Program ($99/yr) — Account Holder uses a permanent personal Apple ID with 2FA on
- ☐ Sign **Paid Applications Agreement** in App Store Connect → Agreements, Tax & Banking (blocks IAPs)
- ☐ Tax form (W-9 US individual)
- ☐ Banking info (where revenue lands)

### Bundle identity
- ✓ Bundle ID `com.henrygawelek.garagetime` consistent across project.yml, Info.plist, entitlements
- ☐ Reserve App Store Name "Garage Time" in App Store Connect (180-day hold)
- ✓ `CFBundleShortVersionString` = `1.0.0`, `CFBundleVersion` = `1` (bump build for every Archive)
- ✓ `LSApplicationCategoryType` = `public.app-category.utilities`
- ✓ `ITSAppUsesNonExemptEncryption` = `false` (no custom crypto)
- ✓ `TARGETED_DEVICE_FAMILY` = `1` (iPhone only — no iPad screenshots required)

### Capabilities + entitlements
- ✓ iCloud / CloudKit entitlement (`iCloud.com.henrygawelek.garagetime`)
- ✓ Push (APNs) `aps-environment = development` — flip to `production` for App Store build
- ✓ Background modes: `fetch`, `processing`, `remote-notification`
- ✓ `BGTaskSchedulerPermittedIdentifiers` includes `com.henrygawelek.garagetime.refresh`
- ☐ Create the iCloud container in developer.apple.com → Identifiers and attach to the App ID
- ☐ Set `DEVELOPMENT_TEAM` on the target (Signing & Capabilities in Xcode)

### Usage description strings
- ✓ `NSCameraUsageDescription` (VIN scan + receipt OCR)
- ✓ `NSPhotoLibraryUsageDescription` + `NSPhotoLibraryAddUsageDescription`
- ✓ `NSMicrophoneUsageDescription` (defensive — VisionKit may probe)

### App icon
- ✓ 1024×1024 PNG at `Assets.xcassets/AppIcon.appiconset/icon-1024.png`
- ✓ `sips -g hasAlpha` returns `no` (App Store rejects alpha)
- ✓ Apple's 26.5 SDK auto-generates all smaller sizes from the master

### Account / privacy
- ✓ No account required — anonymous-first (no Guideline 5.1.1(i) trip)
- ✓ Account deletion: Settings → Data → "Erase all data" wipes local + iCloud copies on sync
- ✓ Privacy Policy + Terms in `docs/index.html` — host via GitHub Pages, link from App Store Connect
- ☐ Wire `docs/` into GitHub Pages and use the resulting URL in App Store Connect → App Privacy
- ✓ Privacy Nutrition Labels: collect zero personal data; CloudKit & NHTSA are the only third parties (declarable as "Not Linked to You")
- ✓ Restore Purchases button on PaywallView (required by App Store guidelines)
- ✓ Subscription disclosures present (auto-renew copy adjacent to CTA + below)

### Onboarding + walkthrough
- ✓ Role-aware onboarding (Mechanic / Customer)
- ✓ Multi-step walkthrough auto-presents after onboarding completes
- ✓ Walkthrough replayable from More → About → "Replay the tour"
- ✓ Per-role step content (8 mechanic steps, 6 customer steps)

### Free trial
- ✓ 7-day local trial implemented (independent of StoreKit intro pricing)
- ✓ Paywall shows "Start free trial" CTA when available, "X days left" banner when active, "Trial ended" hint when expired
- ✓ MoreView shows persistent trial banner with day count + upgrade button
- ✓ Trial promotes Free → CustomerPlus (customer) or Free → ShopStandard (mechanic)
- ✓ Real subscription always wins over local trial
- Note: when StoreKit Configuration is added for App Store, Apple intro pricing takes over the introductory free-trial UX

### Dealer-abuse prevention
- ✓ `VehicleQuotaService` enforces hard tier caps + hourly burst + daily limits
- ✓ NHTSA VIN-verified badge on vehicle cards (discourages junk VINs)
- ✓ Free tier capped at 2 vehicles; rate-limit alerts cite "not built for dealer inventories"

### Bugs fixed in this session
- ✓ Customer-mode estimate picker now includes personal vehicles (was filtering to meCustomer-only)
- ✓ Customer-mode requests view now shows requests with no customer link (was filtering to meCustomer-only)
- ✓ Garage hides "Customers" filter chip when in customer mode (it was always shown)
- ✓ Bulk Import now properly gated behind Shop Pro with a clean upsell screen
- ✓ Quota check uses trial-aware entitlements (was using raw store.entitlements)

### Tests
- ✓ 77 tests, 16 suites, all passing
- ✓ 0 compile warnings
- ✓ 0 force unwraps in production code paths (only intentional `try!` in container fallback)

## Remaining setup the USER must do

Ordered checklist:
1. [ ] Enroll in Apple Developer Program (paid, $99/yr) — needed for CloudKit entitlement, TestFlight, App Store, push notifications.
2. [ ] Sign the Paid Applications Agreement in App Store Connect (Agreements, Tax, Banking) — blocks IAPs until done.
3. [ ] Create the App ID `com.henrygawelek.garagetime` at developer.apple.com → Identifiers.
4. [ ] Create the iCloud container `iCloud.com.henrygawelek.garagetime` and attach to the App ID.
5. [ ] In Xcode, set `DEVELOPMENT_TEAM` on the GarageTime target (or fill it into `project.yml` and regenerate).
6. [ ] Reserve the App Store name "Garage Time" in App Store Connect (180-day hold).
7. [ ] Generate the AppIcon set (1024×1024 master in `Resources/Icon/icon-1024.png`; use Bakery/Icon Slate to export all sizes into `Assets.xcassets/AppIcon.appiconset`).
8. [ ] Stand up GitHub Pages for the privacy policy + support page (`docs/` folder already wired).
9. [ ] (Stage 12) Create three RevenueCat offerings (Pro monthly, Pro yearly, Shop monthly, Shop yearly) OR the equivalent StoreKit 2 products.
10. [ ] (Stage 14) Recruit 5+ TestFlight beta testers; prioritize 2 paying shop owners.
