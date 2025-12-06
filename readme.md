# 一个 macOS 按键监控小工具

## 构建

# 1) 构建 Release
xcodebuild -scheme "key-display" -configuration Release -derivedDataPath build
# 可选：给 app 做个临时签名（仍非公证）
# codesign -s - --deep --force build/Build/Products/Release/key_display.app

# 2) 准备 DMG 内容
mkdir -p dist
cp -R build/Build/Products/Release/key-display.app dist/
ln -s /Applications dist/Applications

# 3) 生成 DMG（就在当前目录生成 KeyDisplay.dmg）
hdiutil create -volname "KeyDisplay" -srcfolder dist -ov -format UDZO KeyDisplay.dmg

# 4) 可选清理
rm -rf dist
