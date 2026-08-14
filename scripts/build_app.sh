#!/bin/bash
set -euo pipefail

project_dir=$(cd "$(dirname "$0")/.." && pwd)
app_dir="$project_dir/dist/快捷键地图.app"
archive_path="$project_dir/dist/Shortcut-Map.app.zip"
signing_root=$(/usr/bin/mktemp -d)
signing_app="$signing_root/快捷键地图.app"

cleanup() {
  /bin/rm -rf "$signing_root"
}
trap cleanup EXIT

cd "$project_dir"
swift build -c release

mkdir -p "$signing_app/Contents/MacOS" "$signing_app/Contents/Resources"
cp ".build/release/ShortcutMap" "$signing_app/Contents/MacOS/ShortcutMap"
cp "Resources/Info.plist" "$signing_app/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$signing_app/Contents/Resources/AppIcon.icns"
/usr/bin/xattr -cr "$signing_app"
codesign --force --deep --sign - \
  --requirements '=designated => identifier "com.kanyun.shortcutmap"' \
  "$signing_app"
codesign --verify --deep --strict --verbose=2 "$signing_app"

/bin/rm -rf "$app_dir"
/bin/rm -f "$archive_path"
/usr/bin/ditto -c -k --keepParent "$signing_app" "$archive_path"

echo "$archive_path"
