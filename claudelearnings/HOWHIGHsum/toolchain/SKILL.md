---
name: toolchain
description: Reference for concrete build / test / verify commands across the iOS + Supabase + media stack. Triggers: "build the app", "run tests", "verify the icon", "deploy edge function", "test the build", "what's the command for X", or any moment of "how do I run this thing".
---

# Toolchain reference

Concrete commands. Copy-paste targets. Generic placeholders in `<angle brackets>`.

## iOS — xcodebuild

```bash
# Sim build (Debug)
xcodebuild -project <App>.xcodeproj -scheme <App> \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# Device build (no install)
xcodebuild -project <App>.xcodeproj -scheme <App> \
  -destination 'generic/platform=iOS' build

# Tests (sim)
xcodebuild -project <App>.xcodeproj -scheme <App> \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test \
  -only-testing:<App>Tests

# Specific test class
xcodebuild ... test -only-testing:<App>Tests/<TestClassName>

# Archive (for distribution)
xcodebuild -project <App>.xcodeproj -scheme <App> \
  -destination 'generic/platform=iOS' \
  -archivePath build/<App>.xcarchive archive

# Export for App Store (after archive)
xcodebuild -exportArchive \
  -archivePath build/<App>.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

For Apple Silicon Macs and recent Xcode: include `-skipPackagePluginValidation` if SPM plugin validation hangs.

## iOS — Simulator screenshots

```bash
# In a running simulator: ⌘+S saves a native-resolution PNG to ~/Desktop
# Or via xcrun:
xcrun simctl io booted screenshot screenshot.png
```

For App Store screenshots, build for the largest current iPhone simulator (iPhone Pro Max) and capture there — Apple wants the largest device's resolution.

## Image / icon verification

```bash
# Check icon has no alpha channel (App Store rejects alpha)
sips -g hasAlpha icon-1024.png        # must say: hasAlpha: no

# Check dimensions
sips -g pixelWidth -g pixelHeight icon-1024.png   # 1024 x 1024

# Strip alpha if present (re-render is better, but this fixes in a pinch)
sips -s format png --setProperty hasAlpha no input.png --out output.png
```

## Video verification (App Preview)

```bash
# Verify dimensions, frame rate, codec
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,codec_name \
  -of default=noprint_wrappers=1 file.mp4

# Want roughly:
#   codec_name=h264
#   width=1080
#   height=1920
#   r_frame_rate=30/1
```

## Supabase

```bash
# Deploy a single edge function
supabase functions deploy <name> --project-ref <project-ref>

# Deploy all functions in current dir
for f in supabase/functions/*/; do
  fn=$(basename "$f")
  [[ "$fn" == _* ]] && continue   # skip _shared, _tests
  supabase functions deploy "$fn" --project-ref <project-ref>
done

# Local Deno tests for shared modules
deno test --allow-all supabase/functions/_tests/

# Run a single Deno test file
deno test --allow-all supabase/functions/_tests/economy_test.ts

# Tail edge function logs (real-time)
supabase functions logs <name> --project-ref <project-ref>
```

Migrations apply via Dashboard → SQL Editor → paste each `0001…N.sql` in order. CLI alternative: `supabase db push` once you trust it.

## Apple JWT regeneration (Sign In with Apple)

The SIWA client secret expires every 180 days. Regen script:

```bash
# Reads .p8 from ~/.<app>-apple-key.p8 by default
python3 scripts/generate_apple_client_secret.py <KEY_ID>

# Output: pasted into Supabase → Authentication → Providers → Apple → Secret Key
```

Calendar reminder for ~170 days post-generation so it never expires in production.

## App Preview video capture

```
1. Plug iPhone into Mac via USB-C
2. QuickTime Player → File → New Movie Recording
3. Click ▼ next to record button → pick iPhone as both Camera AND Microphone
4. Practice the 25-second script 3-4 times before recording
5. Record → ⌘+T trim to 15-30s → File → Export As → 1080p
6. Optional: iMovie pass for title cards (Vertical template)
7. Verify: ffprobe (above) → portrait dims, 30/1 fps, h264
8. Upload via App Store Connect → version page → 6.7" screenshots → App Preview slot
```

## GitHub Pages for privacy policy

```bash
# In repo:
mkdir -p docs
# Author docs/index.html

# Then in GitHub:
# Settings → Pages → Source: main branch / docs folder → Save
# Live at: https://<user>.github.io/<repo>/
```

Use this URL in App Store Connect → App Information → Privacy Policy URL.

## Common one-liners

```bash
# Decode a JWT (paste the JWT after the equals)
python3 -c "import sys, json, base64; t=sys.argv[1].split('.'); \
  print(json.dumps(json.loads(base64.urlsafe_b64decode(t[1]+'==')), indent=2))" \
  "<jwt>"

# List your simulators
xcrun simctl list devices available | grep iPhone

# Boot a specific simulator
xcrun simctl boot "iPhone 17 Pro"

# Reset a simulator (wipes app data)
xcrun simctl erase "iPhone 17 Pro"

# Find files with raw data exports (avoid committing)
find . -path ./.git -prune -o -name "*.json" -size +100k -print
```

## Environment paths to remember

- Apple key file (SIWA + APNs `.p8`): `~/.<app>-apple-key.p8` — gitignored, never committed.
- Documents directory inside the simulator app:
  ```
  ~/Library/Developer/CoreSimulator/Devices/<UUID>/data/Containers/Data/Application/<UUID>/Documents/
  ```
  Find via `print(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path)` in app launch.
- Xcode archives: `~/Library/Developer/Xcode/Archives/<date>/<App>.xcarchive`
- TestFlight crash logs (after Xcode pulls them): Window → Organizer → Crashes.
