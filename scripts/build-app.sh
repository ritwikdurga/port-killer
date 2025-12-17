#!/bin/bash

# Build script for PortKiller.app
set -e

APP_NAME="PortKiller"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building release binary..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$CONTENTS_DIR/Frameworks"

echo "📋 Copying files..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"
cp "Resources/Info.plist" "$CONTENTS_DIR/"

# Copy icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/"
fi

# Copy SPM resource bundles to Contents/Resources
# Then create symlinks in app root (where SPM's Bundle.module looks)
echo "📦 Copying resource bundles..."
for bundle in "$BUILD_DIR"/*.bundle; do
    if [ -d "$bundle" ]; then
        bundle_name=$(basename "$bundle")
        echo "  → $bundle_name"
        ditto "$bundle" "$RESOURCES_DIR/$bundle_name"
        # Symlink in app root for SPM compatibility
        ln -sf "Contents/Resources/$bundle_name" "$APP_DIR/$bundle_name"
    fi
done

# Download Sparkle framework
SPARKLE_VERSION="2.8.1"
SPARKLE_CACHE="/tmp/Sparkle-${SPARKLE_VERSION}"

if [ ! -d "$SPARKLE_CACHE/Sparkle.framework" ]; then
    echo "📥 Downloading Sparkle ${SPARKLE_VERSION}..."
    curl -L -o /tmp/Sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    mkdir -p "$SPARKLE_CACHE"
    tar -xf /tmp/Sparkle.tar.xz -C "$SPARKLE_CACHE"
    rm /tmp/Sparkle.tar.xz
fi

echo "📦 Copying Sparkle.framework..."
ditto "$SPARKLE_CACHE/Sparkle.framework" "$CONTENTS_DIR/Frameworks/Sparkle.framework"

# Remove XPC services (not needed for non-sandboxed apps)
rm -rf "$CONTENTS_DIR/Frameworks/Sparkle.framework/Versions/B/XPCServices"
rm -f "$CONTENTS_DIR/Frameworks/Sparkle.framework/XPCServices"

# Set rpath
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true

# Sign for local testing (release workflow uses Developer ID)
echo "🔏 Signing..."
codesign --force --sign - "$CONTENTS_DIR/Frameworks/Sparkle.framework" 2>/dev/null || true
codesign --force --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ Done: $APP_DIR"
