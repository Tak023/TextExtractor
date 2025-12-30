#!/bin/bash

# Text Extractor Build Script
# This script builds the app as a standalone macOS application

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="TextExtractor"
SCHEME="TextExtractor"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Text Extractor.app"

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

# Check Xcode path
XCODE_PATH=$(xcode-select -p)
if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
    echo "Error: Full Xcode is required (not just Command Line Tools)."
    echo ""
    echo "Please install Xcode from the Mac App Store and run:"
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    echo ""
    exit 1
fi

echo "Using Xcode at: $XCODE_PATH"
echo ""

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app
echo "Building $PROJECT_NAME..."
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
    2>&1 | while read line; do
        # Show progress
        if [[ "$line" == *"Build"* ]] || [[ "$line" == *"Compile"* ]] || [[ "$line" == *"Link"* ]]; then
            echo "  $line"
        fi
    done

# Check if build succeeded
if [ ! -d "$BUILD_DIR/$PROJECT_NAME.xcarchive" ]; then
    echo ""
    echo "Error: Build failed. Check the output above for errors."
    exit 1
fi

# Export the app
echo ""
echo "Exporting application..."
cp -R "$BUILD_DIR/$PROJECT_NAME.xcarchive/Products/Applications/$APP_NAME" "$BUILD_DIR/"

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
    echo "Or simply double-click the app to run it."
    echo ""

    # Open the build folder
    open "$BUILD_DIR"
else
    echo ""
    echo "Error: Application not found after build."
    exit 1
fi
