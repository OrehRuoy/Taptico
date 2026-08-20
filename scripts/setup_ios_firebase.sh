#!/usr/bin/env bash
# Download GodotFirebaseiOS 0.5.6 (same plugin StimPad + Circuit Sort + W4D ship).
# Requires gh + unzip. CI runs this on macOS AFTER setup_ios_apple_plugins_runtime.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${FIREBASE_IOS_VERSION:-0.5.6}"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-firebase-ios-$$"
mkdir -p "$TMP/download" addons
gh release download "$VERSION" \
  --repo SomniGameStudios/godot-firebase-ios \
  --pattern "GodotFirebaseiOS-${VERSION}.zip" \
  --dir "$TMP/download"
unzip -q "$TMP/download/"*.zip -d "$TMP/extracted"
ADDONS_SRC="$(find "$TMP/extracted" -type d -name "GodotFirebaseiOS" -path "*/addons/*" -print -quit)"
if [[ -z "$ADDONS_SRC" ]]; then
  echo "::error::GodotFirebaseiOS addon not found in release zip"
  find "$TMP/extracted" -maxdepth 4 -type d -print
  exit 1
fi
rm -rf addons/GodotFirebaseiOS
cp -R "$ADDONS_SRC" addons/GodotFirebaseiOS

# Analytics-only patch from Circuit Sort / StimPad: do not abort when
# REVERSED_CLIENT_ID is absent, and inject -force_load into the Xcode project.
if [[ -f tools/ios/GodotFirebaseiOS_export_plugin.gd ]]; then
  cp tools/ios/GodotFirebaseiOS_export_plugin.gd addons/GodotFirebaseiOS/export_plugin.gd
  echo "Installed patched GodotFirebaseiOS export_plugin.gd"
fi
rm -rf "$TMP"

if [[ -n "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > addons/GodotFirebaseiOS/GoogleService-Info.plist
  mkdir -p ios
  cp addons/GodotFirebaseiOS/GoogleService-Info.plist ios/GoogleService-Info.plist
  echo "Injected GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST_BASE64"
elif [[ -f ios/GoogleService-Info.plist ]]; then
  cp ios/GoogleService-Info.plist addons/GodotFirebaseiOS/GoogleService-Info.plist
  echo "Copied ios/GoogleService-Info.plist into addon"
elif [[ -f GoogleService-Info.plist ]]; then
  cp GoogleService-Info.plist addons/GodotFirebaseiOS/GoogleService-Info.plist
  mkdir -p ios
  cp GoogleService-Info.plist ios/GoogleService-Info.plist
  echo "Copied ./GoogleService-Info.plist into addon + ios/"
else
  echo "::error::GoogleService-Info.plist not found — set GOOGLE_SERVICE_INFO_PLIST_BASE64"
  exit 1
fi

test -f addons/GodotFirebaseiOS/FirebaseIOS.gd
test -f addons/GodotFirebaseiOS/plugin.cfg
test -f addons/GodotFirebaseiOS/GodotFirebaseiOS.gdextension
test -f addons/GodotFirebaseiOS/GoogleService-Info.plist
test -d addons/GodotFirebaseiOS/frameworks
# GodotFirebaseiOS.gdextension loads SwiftGodotRuntime at process start.
if [[ ! -d addons/GodotApplePluginsRuntime/bin/SwiftGodotRuntime.xcframework ]]; then
  echo "::error::GodotApplePluginsRuntime missing — run scripts/setup_ios_apple_plugins_runtime.sh first"
  echo "         (without it the iOS app closes on launch)."
  exit 1
fi

# App Store 90057: GodotFirebaseiOS.framework needs CFBundleShortVersionString.
if [[ -x /usr/libexec/PlistBuddy ]]; then
  while IFS= read -r -d '' plist; do
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist" >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$plist"
    /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist" >/dev/null 2>&1 \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${VERSION}" "$plist"
    echo "Patched Firebase framework plist: $plist"
  done < <(find addons/GodotFirebaseiOS -path "*/GodotFirebaseiOS.framework/Info.plist" -print0)
fi

# Headless CI never runs EditorPlugin._enable_plugin(), so ensure FirebaseIOS autoload exists.
if ! grep -q '^FirebaseIOS=' project.godot; then
  python3 -c '
from pathlib import Path
p = Path("project.godot")
t = p.read_text(encoding="utf-8")
needle = "AnalyticsService=\"*res://scripts/autoload/analytics_service.gd\"\n"
insert = needle + "FirebaseIOS=\"*res://addons/GodotFirebaseiOS/FirebaseIOS.gd\"\n"
assert needle in t, "AnalyticsService autoload missing from project.godot"
p.write_text(t.replace(needle, insert, 1), encoding="utf-8")
print("Added FirebaseIOS autoload")
'
fi
grep -q '^FirebaseIOS=' project.godot
echo "GodotFirebaseiOS $VERSION ready under addons/"
