#!/bin/bash
# Regenerate AppIcon.appiconset PNGs and AppIcon.icns from Icon Composer artwork.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/GoHomeYou'reDrunk/AppIcon.icon/Assets/Image 5.png"
ICONSET="$ROOT/GoHomeYou'reDrunk/Assets.xcassets/AppIcon.appiconset"
ICNSSET="$ROOT/GoHomeYou'reDrunk/AppIcon.iconset"
ICNS_OUT="$ROOT/GoHomeYou'reDrunk/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source image: $SOURCE" >&2
  exit 1
fi

mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

rm -rf "$ICNSSET"
mkdir -p "$ICNSSET"
cp "$ICONSET"/icon_*.png "$ICNSSET"/
iconutil -c icns "$ICNSSET" -o "$ICNS_OUT"
rm -rf "$ICNSSET"

echo "Updated $ICONSET and $ICNS_OUT"
