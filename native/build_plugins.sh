#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HAPTICS_SRC="$ROOT/native/godot-haptics/src/haptics_plugin.mm"
STOREKIT_SRC="$ROOT/native/godot-storekit/src/storekit_plugin.mm"
HAPTICS_OUT="$ROOT/ios/plugins/haptics"
STOREKIT_OUT="$ROOT/ios/plugins/storekit"
BUILD="$ROOT/build/plugins"
IOS_MIN="16.0"

mkdir -p "$BUILD/device" "$BUILD/sim" "$HAPTICS_OUT" "$STOREKIT_OUT"

compile_static() {
  local src="$1"
  local obj="$2"
  local sdk="$3"
  local arch_flags="$4"
  clang++ -std=c++17 -ObjC++ -fobjc-arc \
    -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
    $arch_flags \
    -mios-version-min="$IOS_MIN" \
    -c "$src" -o "$obj"
}

echo "Building godot-haptics..."
compile_static "$HAPTICS_SRC" "$BUILD/device/haptics.o" iphoneos "-arch arm64"
libtool -static -o "$BUILD/device/libgodot_haptics.a" "$BUILD/device/haptics.o"
compile_static "$HAPTICS_SRC" "$BUILD/sim/haptics.o" iphonesimulator "-arch arm64 -arch x86_64"
libtool -static -o "$BUILD/sim/libgodot_haptics_sim.a" "$BUILD/sim/haptics.o"
rm -rf "$HAPTICS_OUT/Haptics.xcframework" "$HAPTICS_OUT/Haptics.debug.xcframework" "$HAPTICS_OUT/Haptics.release.xcframework"
xcodebuild -create-xcframework \
  -library "$BUILD/device/libgodot_haptics.a" \
  -library "$BUILD/sim/libgodot_haptics_sim.a" \
  -output "$HAPTICS_OUT/Haptics.xcframework"
cp -R "$HAPTICS_OUT/Haptics.xcframework" "$HAPTICS_OUT/Haptics.release.xcframework"
cp -R "$HAPTICS_OUT/Haptics.xcframework" "$HAPTICS_OUT/Haptics.debug.xcframework"

echo "Building godot-storekit..."
compile_static "$STOREKIT_SRC" "$BUILD/device/storekit.o" iphoneos "-arch arm64"
libtool -static -o "$BUILD/device/libgodot_storekit.a" "$BUILD/device/storekit.o"
compile_static "$STOREKIT_SRC" "$BUILD/sim/storekit.o" iphonesimulator "-arch arm64 -arch x86_64"
libtool -static -o "$BUILD/sim/libgodot_storekit_sim.a" "$BUILD/sim/storekit.o"
rm -rf "$STOREKIT_OUT/StoreKit.xcframework" "$STOREKIT_OUT/StoreKit.debug.xcframework" "$STOREKIT_OUT/StoreKit.release.xcframework"
xcodebuild -create-xcframework \
  -library "$BUILD/device/libgodot_storekit.a" \
  -library "$BUILD/sim/libgodot_storekit_sim.a" \
  -output "$STOREKIT_OUT/StoreKit.xcframework"
cp -R "$STOREKIT_OUT/StoreKit.xcframework" "$STOREKIT_OUT/StoreKit.release.xcframework"
cp -R "$STOREKIT_OUT/StoreKit.xcframework" "$STOREKIT_OUT/StoreKit.debug.xcframework"

echo "Plugins built successfully."
