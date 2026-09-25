#!/usr/bin/env bash
# Verify Taptico IPA contains Haptics + StoreKit and no Firebase.
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
  if [[ "$EXPORTED" -ne 0 ]]; then
    echo "::error::Firebase is still linked. This release ships without analytics."
    fail=1
  fi
fi

if find "$APP" -name 'GoogleService-Info.plist' -print -quit | grep -q .; then
  echo "::error::GoogleService-Info.plist is still in the app bundle"
  fail=1
fi

if find "$APP/Frameworks" -path '*/GodotFirebaseiOS.framework' -print -quit | grep -q .; then
  echo "::error::GodotFirebaseiOS.framework is still in the app bundle"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "::error::IPA plugin verification failed."
  exit 1
fi
echo "IPA plugin verification passed"
