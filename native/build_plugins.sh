#!/usr/bin/env bash
# Build Haptics + StoreKit xcframeworks for Godot iOS export.
# Xcode 16+: do NOT pass two -arch flags to a single clang -c. That produces a
# binary create-xcframework rejects with:
#   "binaries with multiple platforms are not supported"
# W4D / Spectrum Sync: compile each arch separately, then libtool the sim slices.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HAPTICS_SRC="$ROOT/native/godot-haptics/src/haptics_plugin.mm"
STOREKIT_SRC="$ROOT/native/godot-storekit/src/storekit_plugin.mm"
HAPTICS_OUT="$ROOT/ios/plugins/haptics"
STOREKIT_OUT="$ROOT/ios/plugins/storekit"
BUILD="${RUNNER_TEMP:-$ROOT/build}/taptico-plugins"
IOS_MIN="16.0"

mkdir -p "$BUILD/device" "$BUILD/sim" "$HAPTICS_OUT" "$STOREKIT_OUT"

compile_static() {
  local src="$1"
  local obj="$2"
  local sdk="$3"
  local arch="$4"
  local minflag="$5"
  mkdir -p "$(dirname "$obj")"
  clang++ -std=c++17 -ObjC++ -fobjc-arc \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -arch "$arch" \
    "$minflag" \
    -I "$(dirname "$src")" \
    -c "$src" -o "$obj"
}

pack_plugin() {
  local plugin_name="$1"
  local src="$2"
  local out_dir="$3"
  local stem
  stem="$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]')"

  compile_static "$src" "$BUILD/device/${stem}_arm64.o" iphoneos arm64 "-miphoneos-version-min=$IOS_MIN"
  libtool -static -o "$BUILD/device/lib${stem}.a" "$BUILD/device/${stem}_arm64.o"

  compile_static "$src" "$BUILD/sim/${stem}_arm64.o" iphonesimulator arm64 "-mios-simulator-version-min=$IOS_MIN"
  compile_static "$src" "$BUILD/sim/${stem}_x86_64.o" iphonesimulator x86_64 "-mios-simulator-version-min=$IOS_MIN"
  libtool -static -o "$BUILD/sim/lib${stem}_sim.a" \
    "$BUILD/sim/${stem}_arm64.o" \
    "$BUILD/sim/${stem}_x86_64.o"

  rm -rf "$out_dir/${plugin_name}.xcframework" \
    "$out_dir/${plugin_name}.debug.xcframework" \
    "$out_dir/${plugin_name}.release.xcframework"
  xcodebuild -create-xcframework \
    -library "$BUILD/device/lib${stem}.a" \
    -library "$BUILD/sim/lib${stem}_sim.a" \
    -output "$out_dir/${plugin_name}.xcframework"
  cp -R "$out_dir/${plugin_name}.xcframework" "$out_dir/${plugin_name}.release.xcframework"
  cp -R "$out_dir/${plugin_name}.xcframework" "$out_dir/${plugin_name}.debug.xcframework"
}

echo "Building godot-haptics..."
pack_plugin "Haptics" "$HAPTICS_SRC" "$HAPTICS_OUT"

echo "Building godot-storekit..."
pack_plugin "StoreKit" "$STOREKIT_SRC" "$STOREKIT_OUT"

echo "Plugins built successfully."
