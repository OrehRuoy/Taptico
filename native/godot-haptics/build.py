#!/usr/bin/env python3
"""Build godot-haptics iOS xcframework for debug and release."""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
OUTPUT = ROOT.parent.parent / "ios" / "plugins" / "haptics"
GODOT_VERSION = os.environ.get("GODOT_VERSION", "4.6.3")


def run(cmd, **kwargs):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, **kwargs)


def download_godot_headers():
    headers = BUILD / "godot-headers"
    if (headers / "godot" / "gdextension_interface.h").exists():
        return headers
    BUILD.mkdir(parents=True, exist_ok=True)
    tag = f"{GODOT_VERSION}-stable"
    run([
        "git", "clone", "--depth", "1", "--branch", tag,
        "https://github.com/godotengine/godot.git", str(BUILD / "godot-src"),
    ])
    run(["scons", "platform=ios", "target=template_release", "generate=yes"],
        cwd=BUILD / "godot-src")
    return BUILD / "godot-src" / "platform" / "ios"


def build_variant(configuration: str, suffix: str):
    scheme = "godot-haptics"
    xcodeproj = ROOT / "godot-haptics.xcodeproj"
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
        "ONLY_ACTIVE_ARCH=NO",
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
        "ONLY_ACTIVE_ARCH=NO",
    ])
    device_lib = out_dir / "device.xcarchive" / "Products" / "Library" / "Frameworks" / "godot_haptics.framework" / "godot_haptics"
    sim_lib = out_dir / "sim.xcarchive" / "Products" / "Library" / "Frameworks" / "godot_haptics.framework" / "godot_haptics"
    xcframework = out_dir / f"Haptics.{suffix}.xcframework"
    if xcframework.exists():
        shutil.rmtree(xcframework)
    run([
        "xcodebuild", "-create-xcframework",
        "-framework", str(device_lib.parent),
        "-framework", str(sim_lib.parent),
        "-output", str(xcframework),
    ])
    return xcframework


def main():
    if sys.platform != "darwin":
        print("iOS plugin build requires macOS. Skipping binary build.")
        return 0
    download_godot_headers()
    debug_xcf = build_variant("Debug", "debug")
    release_xcf = build_variant("Release", "release")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    final = OUTPUT / "Haptics.xcframework"
    if final.exists():
        shutil.rmtree(final)
    shutil.copytree(release_xcf, final)
    shutil.copy2(debug_xcf, OUTPUT / "Haptics.debug.xcframework")
    shutil.copy2(release_xcf, OUTPUT / "Haptics.release.xcframework")
    print("Built", final)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
