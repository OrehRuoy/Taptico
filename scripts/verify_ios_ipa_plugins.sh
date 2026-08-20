#!/usr/bin/env bash
# Verify Taptico IPA contains native plugins + Firebase Analytics files.
# Dump strings to a file first — never `strings | grep -q` under pipefail
# (W4D/Circuit Sort: grep -q + SIGPIPE false-fails when the string IS present).
set -euo pipefail
IPA="${1:?Usage: verify_ios_ipa_plugins.sh path/to.ipa}"
TMP=$(mktemp -d)
unzip -q "$IPA" -d "$TMP"
APP=$(find "$TMP/Payload" -maxdepth 1 -name '*.app' | head -1)
BIN="$APP/$(basename "$APP" .app)"
strings "$BIN" > "$TMP/strings.txt"

grep -q 'Haptics' "$TMP/strings.txt" || { echo 'Haptics not found in binary'; exit 1; }
grep -q 'StoreKit' "$TMP/strings.txt" || { echo 'StoreKit plugin marker not found in binary'; exit 1; }
echo "Haptics + StoreKit symbols present in binary"

if [ -f "$APP/GoogleService-Info.plist" ]; then
  echo "GoogleService-Info.plist present in app bundle"
else
  echo "::warning::GoogleService-Info.plist missing from app bundle — Analytics will not initialize"
fi

FB_PLIST=$(find "$APP/Frameworks" -path "*/GodotFirebaseiOS.framework/Info.plist" 2>/dev/null | head -1 || true)
if [ -n "$FB_PLIST" ]; then
  if /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$FB_PLIST" >/dev/null 2>&1; then
    echo "GodotFirebaseiOS.framework CFBundleShortVersionString OK"
  else
    echo "::error::GodotFirebaseiOS.framework missing CFBundleShortVersionString (App Store 90057)"
    exit 1
  fi
else
  echo "::warning::GodotFirebaseiOS.framework not found under Frameworks/"
fi

echo "IPA plugin verification passed"
