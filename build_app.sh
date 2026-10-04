#!/bin/bash
set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Desktop/Quick Loop.app"

echo "=== Quick Loop 빌드 및 데스크톱 앱 업데이트 ==="

if [ ! -x "$GODOT" ]; then
  echo "Godot을 찾을 수 없습니다: $GODOT"
  exit 1
fi

# 1) 아이콘: icon.svg -> icon.icns -> 앱 번들 리소스
if [ "$DIR/icon.svg" -nt "$DIR/icon.icns" ] || [ ! -f "$DIR/icon.icns" ]; then
  echo "-- 아이콘 재생성 (icon.svg -> icon.icns)"
  RM="/tmp/ql.iconset"
  rm -rf "$RM"; mkdir -p "$RM"
  MASTER="/tmp/ql_master.png"
  sips -s format png "$DIR/icon.svg" --out "$MASTER" -Z 1024 >/dev/null
  for s in 16 32 64 128 256 512; do
    sips -s format png "$MASTER" --out "$RM/icon_${s}x${s}.png" -Z $s >/dev/null
    d=$((s * 2))
    [ $d -le 1024 ] && sips -s format png "$MASTER" --out "$RM/icon_${s}x${s}@2x.png" -Z $d >/dev/null
  done
  iconutil -c icns "$RM" -o "$DIR/icon.icns"
  rm -rf "$RM" "$MASTER"
fi

# 2) 앱이 없으면 통째로 새로 내보낸다 (아이콘까지 포함)
if [ ! -d "$APP" ]; then
  echo "-- 앱이 없어 전체 내보내기"
  "$GODOT" --headless --path "$DIR" --export-release "macOS" "$APP"
else
  # 3) 이미 있으면 pck 만 교체하고 아이콘을 덮어쓴다
  "$GODOT" --headless --path "$DIR" --export-pack "macOS" "$APP/Contents/Resources/Quick Loop.pck"
  cp "$DIR/icon.icns" "$APP/Contents/Resources/icon.icns"
  # Info.plist 의 CFBundleIconFile 를 icon 으로 맞춘다
  PLIST="$APP/Contents/Info.plist"
  if ! /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$PLIST" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string icon" "$PLIST"
  else
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile icon" "$PLIST"
  fi
fi

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
touch "$APP"

echo "완료: 데스크톱의 'Quick Loop.app' 갱신됨"
