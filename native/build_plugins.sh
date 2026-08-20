#!/usr/bin/env bash
# Build Haptics + StoreKit xcframeworks for Godot iOS export.
#
# Xcode 16: compile each arch separately, then libtool sim slices.
# Godot 4.6: dummy.cpp calls init/deinit with C++ linkage and does NOT
# auto-register Engine singletons — merge GodotPluginEntry.cpp like W4D.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HAPTICS_SRC="$ROOT/native/godot-haptics/src/haptics_plugin.mm"
STOREKIT_SRC="$ROOT/native/godot-storekit/src/storekit_plugin.mm"
HAPTICS_ENTRY="$ROOT/native/godot-haptics/src/GodotPluginEntry.cpp"
STOREKIT_ENTRY="$ROOT/native/godot-storekit/src/GodotPluginEntry.cpp"
HAPTICS_OUT="$ROOT/ios/plugins/haptics"
STOREKIT_OUT="$ROOT/ios/plugins/storekit"
BUILD="${RUNNER_TEMP:-$ROOT/build}/taptico-plugins"
IOS_MIN="16.0"
GODOT_SOURCE_VERSION="${GODOT_SOURCE_VERSION:-4.6.3}"
GODOT_SRC_CACHE="${GODOT_SRC_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/godot-src}"
GODOT_SRC="$GODOT_SRC_CACHE/godot-${GODOT_SOURCE_VERSION}-stable"

mkdir -p "$BUILD/device" "$BUILD/sim" "$HAPTICS_OUT" "$STOREKIT_OUT"

fetch_godot_headers() {
  if [[ ! -f "$GODOT_SRC/core/config/engine.h" ]]; then
    mkdir -p "$GODOT_SRC_CACHE"
    local tarball="$GODOT_SRC_CACHE/godot-${GODOT_SOURCE_VERSION}-stable.tar.xz"
    echo "Fetching Godot ${GODOT_SOURCE_VERSION} source for engine headers..."
    curl -fsSL -o "$tarball" \
      "https://github.com/godotengine/godot/releases/download/${GODOT_SOURCE_VERSION}-stable/godot-${GODOT_SOURCE_VERSION}-stable.tar.xz"
    tar -xf "$tarball" -C "$GODOT_SRC_CACHE"
  fi
  python3 "$ROOT/scripts/generate_godot_gen_headers.py" "$GODOT_SRC"
}

fetch_godot_headers

SDK_IOS="$(xcrun --sdk iphoneos --show-sdk-path)"
SDK_SIM="$(xcrun --sdk iphonesimulator --show-sdk-path)"
GODOT_INCLUDES=(-I"$GODOT_SRC" -I"$GODOT_SRC/platform/ios")
GODOT_DEFINES=(-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED -DCOREAUDIO_ENABLED -DTHREADS_ENABLED -DNDEBUG)
GODOT_CXXFLAGS=(-std=gnu++17 -fno-exceptions -O2)

compile_mm() {
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

compile_entry() {
  local src="$1"
  local obj="$2"
  local arch="$3"
  local sysroot="$4"
  local minflag="$5"
  mkdir -p "$(dirname "$obj")"
  xcrun clang++ -c "$src" -o "$obj" \
    -arch "$arch" -isysroot "$sysroot" "$minflag" \
    "${GODOT_CXXFLAGS[@]}" "${GODOT_INCLUDES[@]}" "${GODOT_DEFINES[@]}"
}

pack_plugin() {
  local plugin_name="$1"
  local mm_src="$2"
  local entry_src="$3"
  local out_dir="$4"
  local stem
  stem="$(echo "$plugin_name" | tr '[:upper:]' '[:lower:]')"

  compile_mm "$mm_src" "$BUILD/device/${stem}_mm_arm64.o" iphoneos arm64 "-miphoneos-version-min=$IOS_MIN"
  compile_entry "$entry_src" "$BUILD/device/${stem}_entry_arm64.o" arm64 "$SDK_IOS" "-miphoneos-version-min=$IOS_MIN"
  libtool -static -o "$BUILD/device/lib${stem}.a" \
    "$BUILD/device/${stem}_mm_arm64.o" \
    "$BUILD/device/${stem}_entry_arm64.o"

  compile_mm "$mm_src" "$BUILD/sim/${stem}_mm_arm64.o" iphonesimulator arm64 "-mios-simulator-version-min=$IOS_MIN"
  compile_mm "$mm_src" "$BUILD/sim/${stem}_mm_x86_64.o" iphonesimulator x86_64 "-mios-simulator-version-min=$IOS_MIN"
  compile_entry "$entry_src" "$BUILD/sim/${stem}_entry_arm64.o" arm64 "$SDK_SIM" "-mios-simulator-version-min=$IOS_MIN"
  compile_entry "$entry_src" "$BUILD/sim/${stem}_entry_x86_64.o" x86_64 "$SDK_SIM" "-mios-simulator-version-min=$IOS_MIN"
  libtool -static -o "$BUILD/sim/lib${stem}_sim.a" \
    "$BUILD/sim/${stem}_mm_arm64.o" \
    "$BUILD/sim/${stem}_mm_x86_64.o" \
    "$BUILD/sim/${stem}_entry_arm64.o" \
    "$BUILD/sim/${stem}_entry_x86_64.o"

  SYMS="$BUILD/device/syms-${stem}.txt"
  { nm -gU "$BUILD/device/lib${stem}.a" 2>/dev/null | c++filt; } > "$SYMS" || true
  if ! grep -q "${stem}_init()" "$SYMS"; then
    echo "ERROR: ${stem}_init() C++ symbol not found in $BUILD/device/lib${stem}.a"
    cat "$SYMS" || true
    exit 1
  fi

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
pack_plugin "Haptics" "$HAPTICS_SRC" "$HAPTICS_ENTRY" "$HAPTICS_OUT"

echo "Building godot-storekit..."
pack_plugin "StoreKit" "$STOREKIT_SRC" "$STOREKIT_ENTRY" "$STOREKIT_OUT"

echo "Plugins built successfully."
