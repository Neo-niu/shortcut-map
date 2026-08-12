#!/bin/bash
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
app_dir="$project_dir/dist/快捷键地图.app"

cd "$project_dir"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp ".build/release/ShortcutMap" "$app_dir/Contents/MacOS/ShortcutMap"
cp "Resources/Info.plist" "$app_dir/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - \
  --requirements '=designated => identifier "com.kanyun.shortcutmap"' \
  "$app_dir"

echo "$app_dir"
