#!/usr/bin/env bash
# Install GodotApplePluginsRuntime (SwiftGodotRuntime.xcframework).
# GodotFirebaseiOS.gdextension depends on it — without it the TestFlight app
# closes immediately on launch (dyld missing SwiftGodotRuntime).
# Same pin as StimPad + Circuit Sort + What's 4 Dinner.
# StoreKit/GameCenter from that repo are NOT installed; Taptico uses native/godot-storekit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PIN="${GODOT_APPLE_PLUGINS_PIN:-build-3781b9c19eaf69b2387eacecf4b6f88fc8d07e65}"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-apple-plugins-$$"
mkdir -p "$TMP/download" addons
# Extract outside the Godot project so the zip isn't scanned as duplicate resources.
gh release download "$PIN" \
  --repo migueldeicaza/GodotApplePlugins \
  --pattern "*.zip" \
  --dir "$TMP/download"
unzip -q "$TMP/download/"*.zip -d "$TMP/extracted"
ADDONS_SRC="$(find "$TMP/extracted" -type d -name "addons" -print -quit)"
if [[ -z "$ADDONS_SRC" ]]; then
  echo "::error::addons folder not found in GodotApplePlugins release zip"
  find "$TMP/extracted" -maxdepth 4 -type d -print
  exit 1
fi
if [[ ! -d "$ADDONS_SRC/GodotApplePluginsRuntime" ]]; then
  echo "::error::GodotApplePluginsRuntime not found in release zip"
  ls "$ADDONS_SRC"
  exit 1
fi
rm -rf addons/GodotApplePluginsRuntime
cp -R "$ADDONS_SRC/GodotApplePluginsRuntime" addons/
rm -rf "$TMP"
test -d addons/GodotApplePluginsRuntime/bin/SwiftGodotRuntime.xcframework
echo "GodotApplePluginsRuntime ($PIN) ready under addons/"
