#!/bin/bash
# Regenerate GarageTime.xcodeproj from project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not installed. brew install xcodegen"
  exit 1
fi
xcodegen generate
echo "✓ Regenerated GarageTime.xcodeproj"
