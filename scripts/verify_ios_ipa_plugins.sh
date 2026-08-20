#!/usr/bin/env bash
# Verify Taptico IPA contains native plugins + Firebase Analytics files.
# Dump strings to a file first — never `strings | grep -q` under pipefail
# (W4D/Circuit Sort: grep -q + SIGPIPE false-fails when the string IS present).
set -euo pipefail
IPA="${1:?Usage: verify_ios_ipa_plugins.sh path/to.ipa}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -q "$IPA" -d "$TMP"
APP=$(find "$TMP/Payload" -maxdepth 1 -name '*.app' | head -1)
BIN="$APP/$(basename "$APP" .app)"
if [[ -z "${APP:-}" || ! -f "$BIN" ]]; then
  echo "::error::Could not locate app executable inside IPA"
  exit 1
fi
strings -a "$BIN" > "$TMP/strings.txt"
fail=0

grep -q 'Haptics' "$TMP/strings.txt" || { echo '::error::Haptics not found in binary'; fail=1; }
grep -q 'StoreKit' "$TMP/strings.txt" || { echo '::error::StoreKit plugin marker not found in binary'; fail=1; }
echo "Haptics + StoreKit symbols present in binary"

if command -v nm >/dev/null 2>&1; then
  EXPORTED=$(nm -gU "$BIN" 2>/dev/null | grep -c 'FirebaseAuth\|FIRApp\|FirebaseCore' || true)
  echo "Firebase symbols exported by IPA binary: $EXPORTED"
  if [[ "$EXPORTED" -eq 0 ]]; then
    echo "::error::IPA exports no Firebase symbols; GodotFirebaseiOS.framework will crash on launch"
    fail=1
  fi
fi

GSPLIST="$APP/GoogleService-Info.plist"
if [[ -f "$GSPLIST" ]]; then
  strings -a "$GSPLIST" > "$TMP/gsplist_strings.txt"
  if grep -q "1:1070208231804:ios:7606d6119251869f101cf9" "$TMP/gsplist_strings.txt"; then
    echo "GoogleService-Info.plist present with Taptico iOS GOOGLE_APP_ID"
  else
    echo "::error::GoogleService-Info.plist present but missing Taptico iOS GOOGLE_APP_ID"
    fail=1
  fi
else
  echo "::error::MISSING: GoogleService-Info.plist in app bundle (GodotFirebaseiOS export plugin)"
  fail=1
fi

SWIFT_RT="$(find "$APP/Frameworks" -path "*/SwiftGodotRuntime.framework" -print -quit || true)"
if [[ -n "$SWIFT_RT" ]]; then
  echo "OK: SwiftGodotRuntime.framework present (GodotFirebaseiOS GDExtension dependency)"
else
  echo "::error::MISSING: SwiftGodotRuntime.framework — GodotFirebaseiOS will close the app on launch"
  fail=1
fi

FB_PLIST=$(find "$APP/Frameworks" -path "*/GodotFirebaseiOS.framework/Info.plist" -print -quit || true)
if [[ -n "$FB_PLIST" ]]; then
  if /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$FB_PLIST" >/dev/null 2>&1; then
    echo "GodotFirebaseiOS.framework CFBundleShortVersionString OK"
  else
    echo "::error::GodotFirebaseiOS.framework missing CFBundleShortVersionString (App Store 90057)"
    fail=1
  fi
else
  echo "::error::MISSING: GodotFirebaseiOS.framework under Frameworks/"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "::error::IPA plugin verification failed."
  exit 1
fi
echo "IPA plugin verification passed"
