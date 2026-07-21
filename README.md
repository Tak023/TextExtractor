# TextExtractor

A lightweight macOS menu bar application for extracting text from any area of your screen using OCR (Optical Character Recognition). Similar to popular tools like TextSniper, TextExtractor allows you to quickly capture and copy text from images, PDFs, videos, or any on-screen content.

## Features

- **Quick Screen Capture**: Press a global hotkey to instantly start selecting a screen region
- **Accurate OCR**: Uses Apple's Vision framework (via ScreenCaptureKit) with smart line grouping for correctly ordered text
- **Four Capture Modes**:
  - **With Line Breaks** (⇧⌘7): Preserves the original line structure of the text
  - **Without Line Breaks** (⇧⌘8): Joins all text into a single continuous string
  - **Capture & Speak** (⇧⌘9): Captures text and reads it aloud using Text-to-Speech
  - **Capture & Append** (⇧⌘0): Adds the capture to the existing clipboard contents instead of replacing them
- **Capture History**: The last 10 captures are kept in the menu bar (Recent Captures) — click any entry to re-copy it
- **Copy Preview HUD**: A small floating "Copied ✓" panel shows a preview of what was captured (toggle in Settings)
- **QR & Barcode Detection**: QR codes and barcodes in the selection are decoded and their payloads copied along with the text
- **Recognition Language**: Auto-detect or pin OCR to one of 10 languages (Settings → Recognition Language)
- **Table Column Detection**: Optionally emit tabs between detected columns so captures paste cleanly into spreadsheets (Settings → Detect Table Columns)
- **Launch at Login**: One-click toggle in Settings
- **Text-to-Speech**: Have captured text read aloud with adjustable speech rate
- **Visual Feedback**: Dark overlay with selection rectangle and dimension display
- **Audio Confirmation**: Plays a sound when text is successfully copied
- **Menu Bar Access**: Convenient menu bar icon (📋) for quick access
- **Lightweight**: Minimal resource usage, runs quietly in the background

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Screen Recording permission (required for screen capture)
- Accessibility permission (required for global hotkeys)

## Installation

### Pre-built Application

1. Download the latest release from the Releases page
2. Move `TextExtractor.app` to your `/Applications` folder
3. Launch the application
4. Grant the required permissions when prompted:
   - **Screen Recording**: System Settings → Privacy & Security → Screen Recording → Enable TextExtractor
   - **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable TextExtractor

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/TextExtractor.git
   cd TextExtractor
   ```

2. Build using Xcode:
   ```bash
   xcodebuild -project TextExtractor.xcodeproj \
     -scheme TextExtractor \
     -configuration Release \
     -derivedDataPath build \
     build
   ```

3. The built application will be located at:
   ```
   build/Build/Products/Release/TextExtractor.app
   ```

4. Copy to Applications:
   ```bash
   cp -R build/Build/Products/Release/TextExtractor.app /Applications/
   ```

5. (Optional) Sign the application:
   ```bash
   codesign --force --deep --sign - --identifier "com.textextractor.app" /Applications/TextExtractor.app
   ```

## Project Structure

```
TextExtractor/
├── TextExtractor.xcodeproj/     # Xcode project file
├── TextExtractor/
│   ├── App/
│   │   └── AppDelegate.swift    # Main application logic, hotkeys, overlay, OCR
│   ├── Models/
│   │   └── Constants.swift      # App constants and configuration
│   ├── Services/
│   │   └── OCRService.swift     # OCR service wrapper (alternative implementation)
│   ├── Utilities/
│   │   └── String+Extensions.swift  # String helper extensions
│   └── Views/                   # Additional view components
├── build.sh                     # Build script
├── launch.sh                    # Launch script (runs with proper permissions)
└── README.md                    # This file
```

### Key Components

- **AppDelegate.swift**: Contains all core functionality including:
  - Status bar menu setup
  - Global hotkey registration (Carbon Events)
  - Selection overlay window and view
  - Screen capture using `CGWindowListCreateImage`
  - OCR processing using Vision framework
  - Clipboard management

- **SelectionOverlayView**: Custom NSView that handles:
  - Mouse tracking for region selection
  - Visual feedback (dark overlay, selection rectangle)
  - Crosshair cursor management
  - Keyboard events (Escape to cancel)

## Usage

### Starting the Application

Launch TextExtractor from your Applications folder or use the provided launch script:
```bash
./launch.sh
```

### Capturing Text

1. **Using Hotkeys**:
   - Press `⇧⌘7` (Shift+Command+7) to capture with line breaks preserved
   - Press `⇧⌘8` (Shift+Command+8) to capture without line breaks
   - Press `⇧⌘9` (Shift+Command+9) to capture and have the text read aloud
   - Press `⇧⌘0` (Shift+Command+0) to capture and append to the current clipboard contents

2. **Using the Menu**:
   - Click the 📋 icon in the menu bar
   - Select one of the four capture modes
   - Use "Recent Captures" to re-copy any of the last 10 captures
   - Use "Stop Speaking" to interrupt text-to-speech playback
   - Use "Settings" to change recognition language, toggle table-column detection, the copy preview, or launch at login

3. **Selecting a Region**:
   - A dark overlay will appear over your screen
   - Click and drag to select the area containing text
   - Release the mouse button to capture
   - Press `Escape` to cancel

4. **Result**:
   - The extracted text is automatically copied to your clipboard
   - Any QR codes or barcodes in the selection are decoded and included
   - A sound confirms successful capture, and a small "Copied ✓" preview appears (if enabled)
   - Paste the text anywhere using `⌘V`
   - If using Capture & Speak, the text will be read aloud automatically

### Text-to-Speech Settings

You can adjust the speech rate in Preferences (click the menu bar icon → Preferences → General):
- Use the Speech Rate slider to control how fast text is read aloud
- Rate ranges from 0.5x (slower) to 2.0x (faster)
- Default rate is 1.0x (normal speed)

### Quitting the Application

- Click the 📋 menu bar icon and select "Quit"
- Or press `⌘Q` when the menu is open

## Troubleshooting

### Hotkeys Not Working

1. Ensure Accessibility permission is granted:
   - System Settings → Privacy & Security → Accessibility
   - Find TextExtractor and enable it
2. Restart the application after granting permission

### Screen Capture Shows Only Wallpaper / No Text Detected

1. Ensure Screen Recording permission is granted:
   - System Settings → Privacy & Security → Screen Recording
   - Find TextExtractor and enable it
2. Restart the application after granting permission

### Permissions Not Being Recognized

If permissions show as granted but the app doesn't work:

1. Quit TextExtractor completely
2. Remove it from the permission lists in System Settings
3. Delete and reinstall the application
4. Re-grant permissions
5. Restart your Mac if issues persist

### Running from Terminal

For best permission handling, run directly from Terminal:
```bash
/Applications/TextExtractor.app/Contents/MacOS/TextExtractor &
```

### Debug Logging

The application writes debug logs to `/tmp/textextractor_debug.log`. Check this file for troubleshooting:
```bash
cat /tmp/textextractor_debug.log
```

Debug captures are saved to `/tmp/textextractor_capture.png` for verification.

## Technologies Used

- **Swift 5**: Primary programming language
- **AppKit**: macOS UI framework for menu bar app and overlay window
- **Vision Framework**: Apple's machine learning framework for OCR
- **AVFoundation**: Text-to-Speech synthesis via `AVSpeechSynthesizer`
- **Core Graphics**: Screen capture via `CGWindowListCreateImage`
- **Carbon Events**: Global hotkey registration (`RegisterEventHotKey`)
- **AudioToolbox**: System sound playback

## License

MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Inspired by [TextSniper](https://textsniper.app/) and similar OCR tools
- Built using Apple's powerful Vision framework for accurate text recognition

