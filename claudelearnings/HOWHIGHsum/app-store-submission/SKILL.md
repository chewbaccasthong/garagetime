---
name: app-store-submission
description: Use when shipping a SwiftUI/UIKit iOS app through the App Store — covers Apple Developer Program enrollment, App Store Connect setup, code signing, screenshots and App Preview specs, metadata writing, privacy policy + Nutrition Labels, age rating, TestFlight, the Archive→Submit flow, and rejection patterns. Load whenever the user is enrolling in the Developer Program, configuring App Store Connect, archiving a build, generating screenshots, writing app metadata, dealing with a rejection, setting up TestFlight, registering an APNs/SIWA key, or saying things like "submit to App Store", "App Store rejected", "TestFlight build", "Archive in Xcode", "provisioning profile", "App Store screenshots", "privacy nutrition labels", "App Store Connect", "Distribute App".
applies_to: any iOS app submission. Skip details about the specific TOSS app — patterns here are portable.
---

# Shipping iOS apps to the App Store

Durable lessons from a first shipped iOS app. Every section ends in a checklist or list of concrete gotchas. None of this is app-specific.

## Apple Developer Program enrollment

Free tier is dev-only:
- 7-day signed builds installed via Xcode → personal device.
- **No** TestFlight, **no** App Store, **no** Sign In with Apple, **no** APNs, **no** DeviceCheck, **no** Game Center, **no** iCloud entitlements.
- Symptom when you forget: "personal development teams do not support [capability]" — switch the Team dropdown to a paid team.

Paid tier ($99/yr):
- Individual: ~24–48h to activate. Just credit card + 2FA on the Apple ID.
- Organization: needs a **D-U-N-S number** (free from Dun & Bradstreet, ~5–7 business days) plus articles of incorporation. Total 2–4 weeks.
- Use a **personal Apple ID you control forever** as the Account Holder. Losing access = bricking.

Day-one checklist:
- [ ] Enroll in the Developer Program; Account Holder uses a permanent personal email.
- [ ] Turn on 2FA on the Account Holder Apple ID.
- [ ] (Org only) Start the D-U-N-S request in parallel with code work.
- [ ] Sign Paid Applications agreement in App Store Connect → Agreements, Tax, and Banking.
- [ ] Add tax forms (W-9 US, W-8BEN non-US individual).
- [ ] Add banking info before submitting any IAP.
- [ ] Calendar reminders for: distribution cert renewal (1y), SIWA JWT client secret (180d), any APNs key rotation cadence.

## App Store Connect setup

First-app checklist:
- [ ] App record created with permanent **Bundle ID** (`com.<you>.<app>`, reverse-DNS, never reused).
- [ ] App **Name** reserved (≤30 chars; held 180 days once reserved).
- [ ] **SKU** set (any internal string, never user-visible).
- [ ] Primary language set; localizations added later.
- [ ] **Category** chosen at first archive (LSApplicationCategoryType in build settings can pre-fill).
- [ ] App Store Connect roles delegated by role, not by sharing creds (Admin / Developer / Marketing / Customer Support).
- [ ] Account Holder credentials never shared — only one person holds them.

Build numbering:
- `CURRENT_PROJECT_VERSION` (CFBundleVersion) **must monotonically increase**. Once a build hits TestFlight processing it cannot be re-uploaded with the same number.
- `MARKETING_VERSION` (CFBundleShortVersionString) is the user-visible "1.0", "1.0.1". Bump when shipping a release; build number bumps on every Archive.

## Code signing and provisioning

- Use **automatic signing** ("Automatically manage signing" in Signing & Capabilities). Manual provisioning is only worth it for enterprise / CI / multi-team setups.
- Selected **Team** in Xcode must be the paid Developer Program team for any privileged capability (SIWA, APNs, DeviceCheck). Personal teams can't use them even with the capability box checked.
- **Bundle ID** in Xcode must exactly match the ID registered at developer.apple.com → Identifiers AND in App Store Connect.
- Adding a capability (Push, SIWA, Sign in with Apple, Background Modes) regenerates the App ID profile on Apple's side and forces a re-sign — let Xcode auto-fix.
- **Distribution certificate**: one per team, valid 1 year, auto-renewed. Don't manually revoke unless instructed.
- **Validate before Distribute**: Organizer → Validate App catches missing entitlements, icon issues, missing usage description strings. Fix every warning before Distribute App.

## Info.plist + Archive gotchas

- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` skips the export-compliance prompt on every Archive. Set to NO if you only use HTTPS / Apple-provided crypto. Set YES + add classification keys if you ship custom crypto.
- **App icon must have no alpha channel** — App Store rejects on upload. If you render programmatically, use `noneSkipLast` / `noneSkipFirst` bitmap info, not `premultipliedLast`. Verify with `sips -g hasAlpha icon-1024.png` (must say `no`).
- `TARGETED_DEVICE_FAMILY`: `1` = iPhone, `2` = iPad, `1,2` = both. Including iPad makes iPad screenshots required and Apple reviews on iPad. Drop iPad from the device family if you don't intend to support it.
- **Even iPhone-only apps may be reviewed on iPad** in iPhone-compatibility mode. Test launch on a real iPad before first submission.
- Every system permission you touch needs a **usage description string** in Info.plist (`NSCameraUsageDescription`, `NSMotionUsageDescription`, `NSPhotoLibraryUsageDescription`, etc.). Missing strings → instant crash when the API is called → reject.
- Set `CFBundleDisplayName` if the user-visible app name differs from the executable name.

## Screenshots

Required sizes (current Apple expectations, check the active list at submission time):
- **6.9" iPhone Pro Max** (1320×2868) — mandatory; covers the largest current iPhone.
- **6.7" iPhone Plus / older Pro Max** (1290×2796) — accepted as fallback if you only have 6.7".
- **6.5" iPhone** (1242×2688) — fallback only.
- **iPad Pro 12.9"** (2048×2732) — required only if you support iPad.

Rules:
- 3–10 screenshots per size. **First three** appear on the listing without scrolling — your strongest frames go there.
- Caption + bezel mock-up lifts conversion ~10–30% (Apple's own data). Keep captions to 4–6 words.
- **No Lorem Ipsum**, no obvious placeholder names. Use realistic mock data.
- Don't manipulate the status bar — simulator screenshots ship a clean status bar by default.

Generation flow that works:
1. Build for the largest current iPhone simulator.
2. Set up the screen state (seed mock data if needed).
3. ⌘+S in the Simulator saves a native-resolution PNG to ~/Desktop.
4. Repeat for 6–8 frames: home, primary action, payoff/result, 2–3 differentiating features, social/share if relevant.
5. Optional: drop into Figma / Rotato / Screenshots.pro to add captions + bezels.

## App Preview video (optional)

Lifts conversion ~25%. Worth ~60 minutes.

Hard specs (Apple-enforced):
- **15–30 seconds**, no exception.
- Portrait, 886×1920 or 1080×1920.
- 30 fps, H.264, MOV/MP4, optional stereo audio.
- Footage of YOUR app on screen — no marketing renders, no third-party logos, no Android references, no still images >2s, no price text.
- Up to 3 videos per device size.

Capture flow:
1. Plug iPhone into Mac.
2. QuickTime → File → New Movie Recording → ▼ next to record → pick iPhone as camera AND mic.
3. Record. Trim with ⌘+T. Export 1080p.
4. Optional: drop into iMovie for a title card (iMovie's "Vertical" template keeps dimensions).
5. Verify dimensions: `ffprobe -v error -show_entries stream=width,height,r_frame_rate <file>`.

Common preview rejections: third-party logos visible, "DOWNLOAD NOW" CTA referring to anything but your app, frame rate drop, footage that doesn't match shipped behavior.

## Metadata: name, subtitle, description, keywords

- **App Name** (≤30 chars): becomes the user-facing name. Avoid bare generics ("Game", "Tracker") unless your brand is strong. Apple rejects ranking-style names that include other brand keywords ("Game for Friends" patterns).
- **Subtitle** (≤30 chars): indexed for search. Lead with a benefit, not a feature.
- **Description** (≤4000 chars): first 2–3 lines visible above "more". Lead with the dare/promise/question. Apple shows the first ~170 chars in search results.
- **Promotional Text** (≤170 chars): editable WITHOUT resubmission. Use for time-limited promos / launch / version call-outs.
- **Keywords** (≤100 chars total, comma-separated):
  - Don't repeat the app name (already indexed).
  - Don't include competitor names (rejection risk).
  - Singular forms only — Apple stems plurals.
  - Localize per language.
- **Support URL**: required, must be live. A one-page docs site (GitHub Pages, Notion, Carrd) is fine.
- **Marketing URL**: optional, can point to the same page.
- **Privacy Policy URL**: required, see below.

Keyword research, ~30 min:
- Free tier of AppFigures / SensorTower / TheTool to see search volume vs difficulty.
- Aim moderate-volume / low-difficulty. Head terms ("game", "fitness") are unwinnable as a new app.
- Mine your own App Store Connect → Search Ads → keyword recommendations after launch — Apple gives the most accurate volume signals there.

## Privacy policy + Nutrition Labels

- **Privacy Policy URL is required** for every app, including ones that collect zero data. Page must be live before submission.
- Cheapest viable host: a `docs/index.html` in the repo, GitHub Pages enabled (Settings → Pages → main / docs). Free, version-controlled, instantly editable.
- Cover at minimum:
  - What data is collected (motion, account, IAP receipts, analytics, crash logs).
  - Where it's stored / which third parties handle it.
  - **Account deletion path** — must be one-tap in-app per **Guideline 5.1.1(v)**. The privacy page just describes it; the app must implement it.
  - Contact email for privacy requests (a real inbox, not a forwarder that bounces).

**Privacy Nutrition Labels** are separate from the URL — App Store Connect → App Privacy → questionnaire. Walk it honestly; Apple cross-references answers against entitlements + SDK signatures in the binary.
- `MetricKit` / Apple crash reports count as data collection.
- Server-side analytics (PostHog, Amplitude, Mixpanel) must be declared even if anonymized.
- "Linked to user" vs "not linked" hinges on whether the account ID can be tied back to a person — anonymous-first auth that never collects PII can mark most fields "not linked".

## Age rating

App Store Connect → App Information → Age Rating questionnaire. ~17 questions on violence, sexual content, gambling, drugs, profanity, web content, simulated gambling, contests, UGC.

The auto-computed rating (4+ / 9+ / 12+ / 17+) is **final** — no manual downgrade.

Rating-bump triggers:
- **Any free-text user-generated content** (even a nickname) → forces 12+ unless you describe content moderation.
- Web links to the open internet → 12+ or 17+.
- Real-money gambling adjacency (loot boxes, paid spins) → 17+.
- Suggestive themes / mild cartoon violence → 9+.

If the app's premise involves risk-of-injury behavior, mark it as cartoon/fantasy violence rather than realistic to keep a sane rating.

## TestFlight

- **Internal testing**: up to 100 testers from your App Store Connect team. Builds appear within ~10 min of upload. No Apple review.
- **External testing**: up to 10,000 testers via public link or invite. Requires a one-time **Beta App Review** (~24h, lighter than full App Store review). Subsequent builds without significant changes don't re-review.
- Build retention: **90 days from upload**. After that, the build expires for testers.
- "What to Test" notes are required and shown to testers — be specific ("try the new replay screen, especially mid-game pause" beats "test everything").
- **Run TestFlight external for at least one full week before App Store submission.** Real users find onboarding / copy / crash-on-first-launch issues no internal review catches.
- Crash logs surface in Xcode → Organizer → Crashes (paired with App Store Connect → TestFlight → Crashes).

## Submission flow

End-to-end, once metadata + binary are ready:

1. Bump `CURRENT_PROJECT_VERSION` (build number).
2. Set `MARKETING_VERSION` to the release version.
3. Xcode → Product → Archive (or `xcodebuild archive`).
4. Organizer → **Validate App** against App Store Connect. Fix every warning.
5. Organizer → **Distribute App** → App Store Connect → Upload.
6. Wait for processing (5–30 min). Build appears under iOS Builds.
7. App Store Connect → version page → select the processed build.
8. Fill all required metadata (screenshots, description, keywords, support URL, privacy URL, age rating).
9. Answer Export Compliance, Content Rights, Advertising Identifier prompts.
10. **Submit for Review.**
11. Apple review queue: 24–72h typical, up to ~1 week worst case.
12. Approved → choose **manual** or **automatic** release. Manual lets you pick the launch moment.

## Common rejection reasons

The ones that have actually bitten on first submissions:

- **Crash on launch on iPad** — Apple reviews on iPad even for iPhone-only apps. Test on a real iPad. Watch for `MainActor.assumeIsolated` traps from system callbacks (CoreMotion, CoreLocation) landing on non-main dispatch queues; fix with `Task { @MainActor }` hops.
- **App icon has alpha channel** — fails on upload. Re-render flat RGB with a solid background.
- **Build number collision** — re-uploading the same build number after a TestFlight processing failure. Always bump.
- **Missing privacy policy URL** — required even for zero-data apps.
- **Missing account deletion** (Guideline 5.1.1(v)) — every app with sign-in must offer one-tap permanent deletion **in-app**, not a "email us" link.
- **Missing iPad screenshots** when device family includes iPad. Either add iPad screenshots or drop iPad from `TARGETED_DEVICE_FAMILY`.
- **Sign In with Apple not offered** when other social logins are (Guideline 4.8). If you ship Google/Facebook login, SIWA is required as a peer.
- **IAP for digital goods routed through Stripe / web** (Guideline 3.1.1). Digital goods MUST use IAP. Physical goods, real-world services, and B2B subscriptions can use other processors.
- **Missing usage description strings** — calling a permission-gated API without `NSCameraUsageDescription` / `NSMotionUsageDescription` / etc. → reviewer device crashes.
- **Login required to see anything** (Guideline 5.1.1(i)) — if your app has any browsable content, allow it without an account. Anonymous-first auth is the safe pattern.
- **Demo account credentials missing** when login is required and the reviewer can't pass it (phone OTP, paid SaaS) — provide demo creds in App Review Information.
- **Spammy keywords** — repeating the app name, listing competitor names, irrelevant terms.
- **Subscription disclosures missing** — if you ship subscriptions, price/period/auto-renewal language must appear adjacent to the purchase button AND in the description.
- **Background modes claimed but not used** — declaring `UIBackgroundModes` capabilities you don't actually exercise → reject.
- **Push notifications used for marketing without explicit opt-out** (Guideline 4.5.4).
- **Wrapped-website apps** (Guideline 4.2 — minimum functionality). A WebView wrapping mostly-web content gets rejected; add native value.
- **Privacy Nutrition Labels disagree with the binary's entitlements / SDKs** — Apple's automated checks flag this.

When rejected, the resolution center message is usually specific. **Don't argue.** Fix the issue, resubmit with a one-line note in the resolution center describing what changed. Resubmits are typically faster than initial review.

## What I'd do differently next time

- **Enroll in the paid Developer Program day one**, even before any code. The 24–48h activation can stall a launch sprint. Org enrollment is multi-week — start D-U-N-S immediately.
- **Reserve the App Store name** the moment it's chosen (180-day hold).
- **Pick iPhone vs iPad upfront** and lock `TARGETED_DEVICE_FAMILY` accordingly. Adding iPad later is a screenshot+QA tax; removing it later strands users.
- **Wire account deletion + privacy policy URL in the foundation phase**, not in "polish". Both are mandatory; bolting them on late is rework.
- **Borrow a real iPad** before first submission and test launch + first-permission-prompt + onboarding there. iPad rejections are the most common surprise.
- **Run TestFlight external for ≥1 week** with 5+ real users before App Store submission.
- **Set `ITSAppUsesNonExemptEncryption=NO`** in Info.plist during initial setup so every Archive doesn't prompt for export compliance.
- **Keep `docs/index.html` in the repo** for the privacy policy + support page, GitHub-Pages-served. Free, versioned, no DNS/hosting drift.
- **Generate screenshots from the latest simulator size**. Apple deprecates older sizes silently; shipping last year's size pool is fine but missing the current largest is a hold.
- **Plan keywords + subtitle as part of design**, not launch eve. Half the install funnel is App Store search; ASO is not a chore, it's a feature.
- **Mind the rotation calendar**: SIWA client secret expires every **180 days**; distribution cert renews yearly; APNs keys are long-lived but rotation hygiene matters. Calendar reminders the day each is generated.
- **Never share Account Holder credentials**. Use Admin / Developer / Marketing roles. Account Holder access is a bricking risk on team departure.
- **Validate every Archive** (Organizer → Validate App). Catches the icon-alpha / missing-entitlement / missing-usage-string class of rejection at build time, not after a 48h review.
