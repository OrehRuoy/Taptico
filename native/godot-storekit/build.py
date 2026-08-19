#!/usr/bin/env python3
"""Build godot-storekit iOS xcframework for debug and release."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
OUTPUT = ROOT.parent.parent / "ios" / "plugins" / "storekit"
GODOT_VERSION = os.environ.get("GODOT_VERSION", "4.6.3")


def run(cmd, **kwargs):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, **kwargs)


def build_variant(configuration: str, suffix: str):
    scheme = "godot-storekit"
    xcodeproj = ROOT / "godot-storekit.xcodeproj"
    out_dir = BUILD / suffix
    out_dir.mkdir(parents=True, exist_ok=True)
    run([
        "xcodebuild", "archive",
        "-project", str(xcodeproj),
        "-scheme", scheme,
        "-destination", "generic/platform=iOS",
        "-archivePath", str(out_dir / "device.xcarchive"),
        f"CONFIGURATION={configuration}",
        "SKIP_INSTALL=NO",
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
    ])
    run([
        "xcodebuild", "archive",
        "-project", str(xcodeproj),
        "-scheme", scheme,
        "-destination", "generic/platform=iOS Simulator",
        "-archivePath", str(out_dir / "sim.xcarchive"),
        f"CONFIGURATION={configuration}",
        "SKIP_INSTALL=NO",
        "BUILD_LIBRARY_FOR_DISTRIBUTION=YES",
    ])
    device_fw = out_dir / "device.xcarchive" / "Products" / "Library" / "Frameworks" / "godot_storekit.framework"
    sim_fw = out_dir / "sim.xcarchive" / "Products" / "Library" / "Frameworks" / "godot_storekit.framework"
    xcframework = out_dir / f"StoreKit.{suffix}.xcframework"
    if xcframework.exists():
        shutil.rmtree(xcframework)
    run([
        "xcodebuild", "-create-xcframework",
        "-framework", str(device_fw),
        "-framework", str(sim_fw),
        "-output", str(xcframework),
    ])
    return xcframework


def main():
    if sys.platform != "darwin":
        print("iOS plugin build requires macOS. Skipping binary build.")
        return 0
    debug_xcf = build_variant("Debug", "debug")
    release_xcf = build_variant("Release", "release")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    final = OUTPUT / "StoreKit.xcframework"
    if final.exists():
        shutil.rmtree(final)
    shutil.copytree(release_xcf, final)
    shutil.copy2(debug_xcf, OUTPUT / "StoreKit.debug.xcframework")
    shutil.copy2(release_xcf, OUTPUT / "StoreKit.release.xcframework")
    print("Built", final)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
