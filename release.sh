#!/bin/bash
# 打包 .dmg 并(可选)上传到 GitHub Release。
# 用法: ./release.sh [版本号]   e.g. ./release.sh v1.0
set -e
cd "$(dirname "$0")"

VER="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo v1.0)}"
NAME="UsagePet"
APP="ClaudePet.app"
DMG="$NAME-$VER.dmg"
STAGE="/tmp/$NAME-stage"

echo "==> 编译"
./build.sh > /dev/null

echo "==> 准备 DMG 暂存目录"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> 生成 $DMG"
hdiutil create -volname "$NAME $VER" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG" > /dev/null
rm -rf "$STAGE"

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
SIZE=$(du -h "$DMG" | awk '{print $1}')

echo ""
echo "✅ 已生成: $DMG  ($SIZE)"
echo "   SHA256: $SHA"
echo ""
echo "想发布到 GitHub Release，执行:"
echo "   gh release create $VER $DMG --generate-notes --title \"$NAME $VER\""
