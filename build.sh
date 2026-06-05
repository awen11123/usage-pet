#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="ClaudePet.app"
BIN="$APP/Contents/MacOS/ClaudePet"

echo "==> 编译 Swift 源码"
mkdir -p "$APP/Contents/MacOS"
swiftc -O \
    -framework WebKit \
    Sources/Pixel.swift \
    Sources/Pet.swift \
    Sources/Usage.swift \
    Sources/Codex.swift \
    Sources/Web.swift \
    Sources/App.swift \
    Sources/main.swift \
    -o "$BIN"

echo "==> 写入 Info.plist"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudePet</string>
    <key>CFBundleDisplayName</key><string>Claude 用量宠物</string>
    <key>CFBundleIdentifier</key><string>com.awen.claudepet</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>ClaudePet</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> 自签名"
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "==> 完成: $(pwd)/$APP"
