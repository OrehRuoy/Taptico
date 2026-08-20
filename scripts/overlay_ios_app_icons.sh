#!/usr/bin/env bash
# Fill Godot's AppIcon.appiconset with the home-screen sizes App Store Connect
# still requires (120 iPhone, 152 iPad, 167 iPad Pro).
# Do NOT copy ios/AppIcon.appiconset/Contents.json over the export — that file
# is 1024-only and caused TestFlight 90022/90023.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT_DIR="${1:-$ROOT/build}"
SRC="$ROOT/assets/icons/icon_1024.png"
test -f "$SRC"

ICONSET="$(find "$EXPORT_DIR" -type d -name 'AppIcon.appiconset' -print -quit || true)"
if [[ -z "$ICONSET" ]]; then
  echo "::error::AppIcon.appiconset not found under $EXPORT_DIR"
  exit 1
fi

# Keep the 1024 source; do not replace Contents.json with the repo stub.
cp -f "$SRC" "$ICONSET/Icon-1024.png"

resize_icon() {
  local px="$1"
  local dest="$2"
  sips -z "$px" "$px" "$SRC" --out "$dest" >/dev/null
}

# Pixel sizes match Godot 4.6.3 platform/ios/export/export_plugin.cpp get_icon_infos().
resize_icon 58 "$ICONSET/Icon-58.png"
resize_icon 87 "$ICONSET/Icon-87.png"
resize_icon 40 "$ICONSET/Icon-40.png"
resize_icon 60 "$ICONSET/Icon-60.png"
resize_icon 76 "$ICONSET/Icon-76.png"
resize_icon 114 "$ICONSET/Icon-114.png"
resize_icon 80 "$ICONSET/Icon-80.png"
resize_icon 120 "$ICONSET/Icon-120.png"
resize_icon 120 "$ICONSET/Icon-120-1.png"
resize_icon 180 "$ICONSET/Icon-180.png"
resize_icon 167 "$ICONSET/Icon-167.png"
resize_icon 152 "$ICONSET/Icon-152.png"
resize_icon 128 "$ICONSET/Icon-128.png"
resize_icon 192 "$ICONSET/Icon-192.png"
resize_icon 136 "$ICONSET/Icon-136.png"

python3 - "$ICONSET" <<'PY'
import json
import os
import sys

iconset = sys.argv[1]
path = os.path.join(iconset, "Contents.json")
# Godot 4.6 uses idiom+platform (not the old ios-marketing-only stub).
images = []
for filename, size, scale in [
    ("Icon-58.png", "29x29", "2x"),
    ("Icon-87.png", "29x29", "3x"),
    ("Icon-40.png", "20x20", "2x"),
    ("Icon-60.png", "20x20", "3x"),
    ("Icon-76.png", "38x38", "2x"),
    ("Icon-114.png", "38x38", "3x"),
    ("Icon-80.png", "40x40", "2x"),
    ("Icon-120.png", "40x40", "3x"),
    ("Icon-120-1.png", "60x60", "2x"),
    ("Icon-180.png", "60x60", "3x"),
    ("Icon-167.png", "83.5x83.5", "2x"),
    ("Icon-152.png", "76x76", "2x"),
    ("Icon-128.png", "64x64", "2x"),
    ("Icon-192.png", "64x64", "3x"),
    ("Icon-136.png", "68x68", "2x"),
    ("Icon-1024.png", "1024x1024", "1x"),
]:
    entry = {
        "filename": filename,
        "idiom": "universal",
        "platform": "ios",
        "size": size,
    }
    if scale != "1x":
        entry["scale"] = scale
    images.append(entry)

with open(path, "w", encoding="utf-8") as f:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
    f.write("\n")
print(f"Wrote {path} with {len(images)} icon slots")
PY

test -f "$ICONSET/Icon-120-1.png"
test -f "$ICONSET/Icon-152.png"
test -f "$ICONSET/Icon-167.png"
test -f "$ICONSET/Icon-1024.png"
grep -q 'Icon-152.png' "$ICONSET/Contents.json"
grep -q 'Icon-167.png' "$ICONSET/Contents.json"
grep -q 'Icon-120-1.png' "$ICONSET/Contents.json"
echo "AppIcon.appiconset has 120/152/167 home-screen icons"
ls -la "$ICONSET"
