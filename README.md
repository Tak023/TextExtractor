# TextExtractor

A cross-platform application for extracting text from any area of your screen using OCR (Optical Character Recognition). Similar to popular tools like TextSniper, TextExtractor allows you to quickly capture and copy text from images, PDFs, videos, or any on-screen content.

**Available for both macOS and Windows.**

## Features

- **Quick Screen Capture**: Press a global hotkey to instantly start selecting a screen region
- **Accurate OCR**: Uses native OCR engines (Apple Vision on macOS, Windows.Media.Ocr on Windows)
- **Three Capture Modes**:
  - **With Line Breaks**: Preserves the original line structure of the text
  - **Without Line Breaks**: Joins all text into a single continuous string
  - **Capture & Speak**: Captures text and reads it aloud using Text-to-Speech
- **QR Code & Barcode Detection**: Automatically detects and decodes QR codes and barcodes
- **Text-to-Speech**: Have captured text read aloud with adjustable speech rate
- **Visual Feedback**: Dark overlay with selection rectangle and dimension display
- **Audio Confirmation**: Plays a sound when text is successfully copied
- **System Tray/Menu Bar**: Convenient icon for quick access
- **Capture History**: View and manage previously captured text
- **Lightweight**: Minimal resource usage, runs quietly in the background

## Windows Version

### Requirements

- Windows 10 version 1809 or later (Windows 11 recommended)
- .NET 8.0 Runtime (included in self-contained builds)

### Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl+Shift+7` | Capture text with line breaks preserved |
| `Ctrl+Shift+8` | Capture text without line breaks |
| `Ctrl+Shift+9` | Capture text and read aloud |

### Installation

#### Pre-built Application

1. Download the latest Windows release from the Releases page
2. Extract to your preferred location
3. Run `TextExtractor.exe`
4. The app will appear in your system tray

#### Building from Source

1. Install [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

2. Clone the repository:
   powershell
   git clone https://github.com/yourusername/TextExtractor.git
   cd TextExtractor\TextExtractor.Windows

3. Build the application:
   powershell
   dotnet build -c Release

4. Or publish a self-contained executable:
   powershell
   dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true

5. The built application will be located at:

   bin\Release\net8.0-windows10.0.22621.0\win-x64\TextExtractor.exe

### Windows Project Structure

TextExtractor.Windows/
├── TextExtractor.Windows.csproj    # Project file
├── App.xaml / App.xaml.cs          # Application entry point
├── Models/
│   ├── AppSettings.cs              # Settings management
│   └── CaptureResult.cs            # Capture history model
├── Services/
│   ├── AppController.cs            # Main controller
│   ├── ClipboardService.cs         # Clipboard operations
│   ├── HotkeyService.cs            # Global hotkey registration
│   ├── NotificationService.cs      # Toast notifications
│   ├── OCRService.cs               # Windows OCR integration
│   ├── QRCodeService.cs            # QR/Barcode detection
│   ├── ScreenCaptureService.cs     # Screen capture
│   ├── SoundService.cs             # Audio feedback
│   └── SpeechService.cs            # Text-to-Speech
├── Views/
│   ├── MainWindow.xaml             # Settings window
│   └── SelectionOverlayWindow.xaml # Screen selection overlay
├── Resources/
│   └── Styles.xaml                 # Modern UI styles
└── Utilities/
    └── IconGenerator.cs            # Dynamic tray icon

### Windows Settings

Access settings by double-clicking the system tray icon or right-clicking and selecting "Settings":

- **General**: Sound effects, notifications, auto-copy, start at login
- **Speech**: Adjust text-to-speech rate, test speech output
- **Hotkeys**: View configured keyboard shortcuts
- **Advanced**: OCR language selection, QR code detection toggle

## macOS Version

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Screen Recording permission (required for screen capture)
- Accessibility permission (required for global hotkeys)

### Hotkeys

| Hotkey | Action |
|--------|--------|
| `⇧⌘7` (Shift+Command+7) | Capture text with line breaks preserved |
| `⇧⌘8` (Shift+Command+8) | Capture text without line breaks |
| `⇧⌘9` (Shift+Command+9) | Capture text and read aloud |

### Installation

#### Pre-built Application

1. Download the latest macOS release from the Releases page
2. Move `TextExtractor.app` to your `/Applications` folder
3. Launch the application
4. Grant the required permissions when prompted:
   - **Screen Recording**: System Settings → Privacy & Security → Screen Recording → Enable TextExtractor
   - **Accessibility**: System Settings → Privacy & Security → Accessibility → Enable TextExtractor

#### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/TextExtractor.git
   cd TextExtractor

2. Build using Xcode:
   bash
   xcodebuild -project TextExtractor.xcodeproj \
     -scheme TextExtractor \
     -configuration Release \
     -derivedDataPath build \
     build
  

3. The built application will be located at:
   
   build/Build/Products/Release/TextExtractor.app
   

4. Copy to Applications:
   bash
   cp -R build/Build/Products/Release/TextExtractor.app /Applications/
 

### macOS Project Structure

TextExtractor/
├── TextExtractor.xcodeproj/     # Xcode project file
├── TextExtractor/
│   ├── App/
│   │   └── AppDelegate.swift    # Main application logic
│   ├── Models/
│   │   └── Constants.swift      # App constants
│   ├── Services/
│   │   └── OCRService.swift     # OCR service wrapper
│   ├── Utilities/
│   │   └── String+Extensions.swift
│   └── Views/
├── build.sh                     # Build script
├── launch.sh                    # Launch script
└── README.md

### Capturing Text

1. **Using Hotkeys** (recommended):
   - Press the capture hotkey to start selection
   - A dark overlay will appear over your screen
   - Click and drag to select the area containing text
   - Release the mouse button to capture
   - Press `Escape` to cancel

2. **Using the Menu/Tray**:
   - Click the icon in the menu bar (macOS) or system tray (Windows)
   - Select the desired capture mode

3. **Result**:
   - The extracted text is automatically copied to your clipboard
   - A sound confirms successful capture
   - Paste the text anywhere using `⌘V` (macOS) or `Ctrl+V` (Windows)
   - If using Capture & Speak, the text will be read aloud

### Text-to-Speech

- Adjust the speech rate in Settings/Preferences
- Rate ranges from 0.5x (slower) to 2.0x (faster)
- Use "Stop Speaking" to interrupt playback

## Troubleshooting

### Windows

#### Hotkeys Not Working
- Check if another application is using the same hotkey combination
- A warning dialog will appear at startup if hotkey registration fails
- Try running the application as administrator

#### No Text Detected
- Ensure the selected region contains clear, readable text
- Try selecting a larger area around the text
- Check that the OCR language matches the text language in Settings

### macOS

#### Hotkeys Not Working
1. Ensure Accessibility permission is granted:
   - System Settings → Privacy & Security → Accessibility
   - Find TextExtractor and enable it
2. Restart the application after granting permission

#### Screen Capture Shows Only Wallpaper
1. Ensure Screen Recording permission is granted:
   - System Settings → Privacy & Security → Screen Recording
   - Find TextExtractor and enable it
2. Restart the application after granting permission

## Technologies Used

### Windows
- **.NET 8.0**: Runtime framework
- **WPF**: Windows Presentation Foundation for UI
- **Windows.Media.Ocr**: Native Windows OCR API
- **System.Speech**: Text-to-Speech synthesis
- **ZXing.Net**: QR code and barcode detection
- **Hardcodet.NotifyIcon.Wpf**: System tray integration

### macOS
- **Swift 5**: Primary programming language
- **AppKit**: macOS UI framework
- **Vision Framework**: Apple's OCR engine
- **AVFoundation**: Text-to-Speech synthesis
- **Core Graphics**: Screen capture
- **Carbon Events**: Global hotkey registration

## License

MIT License

Copyright (c) 2024-2025

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
- Built using native OCR engines for accurate text recognition on each platform
