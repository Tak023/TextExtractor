#!/bin/bash

# Text Extractor Build Script
# Builds the app as a standalone macOS application.
#
# Primary path: xcodebuild archive.
# Fallback path: direct swiftc toolchain build (used when xcodebuild is
# unavailable, e.g. the Xcode license has not been accepted with sudo).

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="TextExtractor"
SCHEME="TextExtractor"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="TextExtractor.app"
BUNDLE_ID="com.textextractor.app"
ENTITLEMENTS="$PROJECT_DIR/$PROJECT_NAME/TextExtractor.entitlements"

echo "==================================="
echo "  Text Extractor Build Script"
echo "==================================="
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found."
    echo ""
    echo "Please install Xcode from the Mac App Store and run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo ""
    exit 1
fi

# Check Xcode path - fall back to /Applications/Xcode.app via DEVELOPER_DIR
# if xcode-select still points at the Command Line Tools
XCODE_PATH=$(xcode-select -p)
if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
    if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
        XCODE_PATH="$DEVELOPER_DIR"
    else
        echo "Error: Full Xcode is required (not just Command Line Tools)."
        echo ""
        echo "Please install Xcode from the Mac App Store and run:"
        echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        echo ""
        exit 1
    fi
fi

echo "Using Xcode at: $XCODE_PATH"
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app with xcodebuild
echo "Building $PROJECT_NAME with xcodebuild..."
set +e
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$PROJECT_NAME.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    > "$BUILD_DIR/xcodebuild.log" 2>&1
XCODEBUILD_STATUS=$?
set -e

if [ $XCODEBUILD_STATUS -eq 0 ] && [ -d "$BUILD_DIR/$PROJECT_NAME.xcarchive" ]; then
    echo "Exporting application from archive..."
    cp -R "$BUILD_DIR/$PROJECT_NAME.xcarchive/Products/Applications/$APP_NAME" "$BUILD_DIR/"
else
    echo ""
    echo "xcodebuild failed (see $BUILD_DIR/xcodebuild.log)."
    echo "Falling back to direct toolchain build..."
    echo ""

    SDK="$XCODE_PATH/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    SWIFTC="$XCODE_PATH/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
    APP_PATH="$BUILD_DIR/$APP_NAME"

    mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

    echo "Compiling Swift sources..."
    "$SWIFTC" -O -swift-version 5 -target arm64-apple-macos14.0 -sdk "$SDK" \
        -parse-as-library \
        "$PROJECT_DIR/$PROJECT_NAME"/App/*.swift \
        "$PROJECT_DIR/$PROJECT_NAME"/Models/*.swift \
        "$PROJECT_DIR/$PROJECT_NAME"/Services/*.swift \
        "$PROJECT_DIR/$PROJECT_NAME"/Utilities/*.swift \
        "$PROJECT_DIR/$PROJECT_NAME"/Views/*.swift \
        -o "$APP_PATH/Contents/MacOS/$PROJECT_NAME"

    echo "Writing bundle metadata..."
    printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
    cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>TextExtractor</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.textextractor.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>TextExtractor</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2024. All rights reserved.</string>
	<key>NSMainNibFile</key>
	<string></string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSScreenCaptureUsageDescription</key>
	<string>Text Extractor needs screen recording permission to capture text from your screen.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Text Extractor uses speech recognition for text-to-speech features.</string>
</dict>
</plist>
PLIST

    # App icon: use the pre-built icns (no actool needed in fallback builds)
    if [ -f "$PROJECT_DIR/$PROJECT_NAME/Resources/AppIcon.icns" ]; then
        cp "$PROJECT_DIR/$PROJECT_NAME/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/"
        echo "App icon bundled (AppIcon.icns)."
    else
        echo "Warning: AppIcon.icns not found (app icon may be missing)."
    fi
fi

# Sign the app (ad-hoc) with a stable designated requirement.
# Without this, macOS ties the Screen Recording permission to the binary's
# hash, which changes every rebuild — silently breaking capture until the
# permission is re-granted. A stable identifier-based requirement lets the
# TCC grant persist across rebuilds.
echo ""
echo "Signing application (ad-hoc, stable identity)..."
codesign --force --sign - \
    --identifier "$BUNDLE_ID" \
    --entitlements "$ENTITLEMENTS" \
    --requirements '=designated => identifier "com.textextractor.app"' \
    "$BUILD_DIR/$APP_NAME"
codesign --verify --verbose=2 "$BUILD_DIR/$APP_NAME"

# Verify the app exists
if [ -d "$BUILD_DIR/$APP_NAME" ]; then
    echo ""
    echo "==================================="
    echo "  Build Successful!"
    echo "==================================="
    echo ""
    echo "Application built at:"
    echo "  $BUILD_DIR/$APP_NAME"
    echo ""
    echo "To install, run:"
    echo "  cp -R \"$BUILD_DIR/$APP_NAME\" /Applications/"
    echo ""
else
    echo ""
    echo "Error: Application not found after build."
    exit 1
fi
