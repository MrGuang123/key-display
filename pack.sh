#!/usr/bin/env bash
set -euo pipefail

# === 可配置参数 ===
# 自动取脚本所在目录，避免硬编码路径泄露
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$SCRIPT_DIR}"
SCHEME="key-display"
CONFIG="Release"
DERIVED_DATA="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
DMG_NAME="KeyDisplay.dmg"
APP_NAME="key-display.app"
CODESIGN_ID=""        # 如需签名，填入证书名；为空则不签

# === 开始 ===
cd "$PROJECT_ROOT"

echo "🧹 清理旧文件..."
rm -rf "$DERIVED_DATA" "$DIST_DIR" "$DMG_NAME"

echo "🔨 构建 Release..."
MACOSX_DEPLOYMENT_TARGET=15.0 xcodebuild clean -scheme "key-display" -configuration Release -derivedDataPath "$DERIVED_DATA"
MACOSX_DEPLOYMENT_TARGET=15.0 xcodebuild -scheme "key-display" -configuration Release -derivedDataPath "$DERIVED_DATA"

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ 构建失败，未找到 $APP_PATH"
  exit 1
fi

if [[ -n "$CODESIGN_ID" ]]; then
  echo "✍️  签名应用..."
  codesign -s "$CODESIGN_ID" --deep --force "$APP_PATH"
fi

echo "📦 准备 DMG 内容..."
mkdir -p "$DIST_DIR"
cp -R "$APP_PATH" "$DIST_DIR/"

# 用 Finder 生成 Applications 别名，避免无图标占位
osascript -e 'tell application "Finder" to make alias file to POSIX file "/Applications" at POSIX file "'"$DIST_DIR"'"'

echo "💿 生成 DMG..."
hdiutil create -volname "KeyDisplay" -srcfolder "$DIST_DIR" -ov -format UDZO "$DMG_NAME"

echo "✅ 完成: $DMG_NAME"