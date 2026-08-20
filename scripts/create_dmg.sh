#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# Ensure app is built
if [ ! -d "build/PrettierBattery.app" ]; then
    ./scripts/build.sh
fi

echo "==> Creating PrettierBattery.dmg installer..."

DMG_NAME="PrettierBattery.dmg"
VOL_NAME="Prettier Battery"
STAGING_DIR="build/dmg_staging"
RAW_DMG="build/PrettierBattery_raw.dmg"

rm -rf "$STAGING_DIR" "$RAW_DMG" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "build/PrettierBattery.app" "$STAGING_DIR/"

# Create symlink to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# Generate raw hybrid image
echo "--> Creating filesystem image..."
hdiutil makehybrid -hfs -hfs-volume-name "$VOL_NAME" -o "$RAW_DMG" "$STAGING_DIR"

# Convert to compressed read-only DMG
echo "--> Compressing DMG..."
hdiutil convert "$RAW_DMG" -format UDZO -o "$DMG_NAME"

rm -rf "$STAGING_DIR" "$RAW_DMG"

echo "==> DMG successfully created: $PROJECT_DIR/$DMG_NAME"
ls -lh "$DMG_NAME"
