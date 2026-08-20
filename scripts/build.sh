#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> Building Prettier Battery..."

# 1. Generate AppIcon.icns
echo "--> Generating AppIcon..."
mkdir -p build
clang -fobjc-arc -framework Cocoa scripts/generate_icon.m -o build/generate_icon
./build/generate_icon
iconutil -c icns AppIcon.iconset -o build/AppIcon.icns
rm -rf AppIcon.iconset build/generate_icon

# 2. Prepare .app bundle
APP_BUNDLE="build/PrettierBattery.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy Plist & Icon
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp build/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 4. Compile Application
echo "--> Compiling native binary..."
clang -fobjc-arc \
      -O2 \
      -target arm64-apple-macos11.0 \
      -framework Cocoa \
      -framework IOKit \
      -framework ServiceManagement \
      src/main.m \
      src/BatteryInfo.m \
      src/BatteryMonitor.m \
      src/BatteryIconRenderer.m \
      src/AppDelegate.m \
      -o "$APP_BUNDLE/Contents/MacOS/PrettierBattery"

# 5. Ad-hoc code sign
echo "--> Code signing application bundle..."
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
xattr -c -r "$APP_BUNDLE" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Successfully built $APP_BUNDLE!"
