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

# 3. Copy Plist, Icon & Localization resources (use -X to discard extended attributes)
cp -X Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp -X build/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [ -d "Resources" ]; then
    cp -RX Resources/ "$APP_BUNDLE/Contents/Resources/"
fi

# 4. Compile Application
echo "--> Compiling native binary..."
clang -fobjc-arc \
      -O2 \
      -target arm64-apple-macos11.0 \
      -Isrc/Models \
      -Isrc/Protocols \
      -Isrc/Services \
      -Isrc/UI \
      -Isrc/App \
      -framework Cocoa \
      -framework IOKit \
      -framework ServiceManagement \
      src/Models/*.m \
      src/Services/*.m \
      src/UI/*.m \
      src/App/*.m \
      -o "$APP_BUNDLE/Contents/MacOS/PrettierBattery"

# 5. Ad-hoc code sign
echo "--> Code signing application bundle..."
find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
dot_clean -m "$APP_BUNDLE" 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
xattr -c "$APP_BUNDLE" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Successfully built $APP_BUNDLE!"
