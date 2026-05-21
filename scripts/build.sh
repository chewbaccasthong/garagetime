#!/bin/bash
# Build GarageTime for the iPhone 17 Pro simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
SCHEME="GarageTime"
DEVICE="${DEVICE:-iPhone 17 Pro}"
xcodebuild \
  -project GarageTime.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -configuration Debug \
  build | xcbeautify 2>/dev/null || true
