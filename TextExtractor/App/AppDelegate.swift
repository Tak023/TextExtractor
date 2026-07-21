import AppKit
import AudioToolbox
import Carbon
import CoreGraphics
import ScreenCaptureKit
import ServiceManagement
import Vision

// Simple file logger
func log(_ message: String) {
    let logFile = "/tmp/textextractor_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var overlayWindow: NSWindow?
    private var overlayView: SelectionOverlayView?
    private var keepLineBreaks: Bool = true
    private var speakAfterCapture: Bool = false
    private var appendToClipboard: Bool = false
    private var successSound: NSSound?
    private let speechService = SpeechService()
    private var hudWindow: NSPanel?
    private var hudDismissTask: DispatchWorkItem?

    // Hotkey references
    private var hotkeyRef1: EventHotKeyRef?
    private var hotkeyRef2: EventHotKeyRef?
    private var hotkeyRef3: EventHotKeyRef?
    private var hotkeyRef4: EventHotKeyRef?
    private static var shared: AppDelegate?

    // MARK: - Settings (persisted in UserDefaults)

    private enum SettingsKey {
        static let history = "captureHistory"
        static let language = "recognitionLanguage"
        static let detectColumns = "detectColumns"
        static let showPreview = "showCopyPreview"
    }

    private static let languages: [(name: String, code: String)] = [
        ("Auto-Detect", "auto"),
        ("English", "en-US"),
        ("Spanish", "es-ES"),
        ("French", "fr-FR"),
        ("German", "de-DE"),
        ("Italian", "it-IT"),
        ("Portuguese", "pt-BR"),
        ("Chinese (Simplified)", "zh-Hans"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR"),
        ("Russian", "ru-RU"),
    ]

    private let maxHistoryItems = 10
    private var captureHistory: [String] = UserDefaults.standard.stringArray(forKey: SettingsKey.history) ?? []
    private var recognitionLanguage: String = UserDefaults.standard.string(forKey: SettingsKey.language) ?? "auto"
    private var detectColumns: Bool = UserDefaults.standard.bool(forKey: SettingsKey.detectColumns)
    private var showCopyPreview: Bool = UserDefaults.standard.object(forKey: SettingsKey.showPreview) == nil
        ? true
        : UserDefaults.standard.bool(forKey: SettingsKey.showPreview)

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launching...")
        AppDelegate.shared = self
        setupStatusItem()
        setupHotkeys()
        setupLocalMonitor()

        // Preload success sound
        if let sound = NSSound(contentsOfFile: "/System/Library/Sounds/Blow.aiff", byReference: true) {
            successSound = sound
            log("Success sound loaded (Blow)")
        } else {
            log("WARNING: Could not load success sound")
        }

        // Check accessibility permission (needed for global hotkeys)
        let trusted = AXIsProcessTrusted()
        log("Accessibility trusted: \(trusted)")
        if !trusted {
            log("Requesting accessibility access...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }

        // Request screen capture permission
        let screenAccess = CGPreflightScreenCaptureAccess()
        log("Screen capture access: \(screenAccess)")
        if !screenAccess {
            log("Requesting screen capture access...")
            CGRequestScreenCaptureAccess()
        }
        log("App launched successfully")
    }

    private func setupLocalMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.shift, .command]) {
                if event.keyCode == 26 { // 7
                    log("Local monitor: ⇧⌘7 detected")
                    self?.captureWithLineBreaks()
                    return nil
                } else if event.keyCode == 28 { // 8
                    log("Local monitor: ⇧⌘8 detected")
                    self?.captureWithoutLineBreaks()
                    return nil
                }
            }
            return event
        }
        log("Local keyboard monitor set up")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "📋"
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Text (⇧⌘7)", action: #selector(captureWithLineBreaks), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Text No Breaks (⇧⌘8)", action: #selector(captureWithoutLineBreaks), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture & Speak (⇧⌘9)", action: #selector(captureAndSpeak), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture & Append (⇧⌘0)", action: #selector(captureAndAppend), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Recent captures submenu
        let historyItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        let historyMenu = NSMenu()
        if captureHistory.isEmpty {
            let empty = NSMenuItem(title: "No Captures Yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            historyMenu.addItem(empty)
        } else {
            for (index, entry) in captureHistory.enumerated() {
                let item = NSMenuItem(title: menuTitle(for: entry), action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                item.tag = index
                item.toolTip = String(entry.prefix(500))
                historyMenu.addItem(item)
            }
            historyMenu.addItem(NSMenuItem.separator())
            historyMenu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        }
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Stop Speaking", action: #selector(stopSpeaking), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Settings submenu
        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()

        let languageItem = NSMenuItem(title: "Recognition Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in Self.languages {
            let item = NSMenuItem(title: language.name, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = language.code
            item.state = (language.code == recognitionLanguage) ? .on : .off
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        settingsMenu.addItem(languageItem)

        let columnsItem = NSMenuItem(title: "Detect Table Columns (Tabs)", action: #selector(toggleDetectColumns), keyEquivalent: "")
        columnsItem.state = detectColumns ? .on : .off
        settingsMenu.addItem(columnsItem)

        let previewItem = NSMenuItem(title: "Show Copy Preview", action: #selector(togglePreview), keyEquivalent: "")
        previewItem.state = showCopyPreview ? .on : .off
        settingsMenu.addItem(previewItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        settingsMenu.addItem(loginItem)

        settingsItem.submenu = settingsMenu
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func menuTitle(for text: String) -> String {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 45 ? String(trimmed.prefix(45)) + "…" : trimmed
    }

    // MARK: - Menu Actions

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        guard sender.tag >= 0 && sender.tag < captureHistory.count else { return }
        let text = captureHistory[sender.tag]
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        playSuccessSound()
        if showCopyPreview {
            showResultHUD(text, title: "Copied ✓")
        }
        log("History item \(sender.tag) re-copied")
    }

    @objc private func clearHistory() {
        captureHistory.removeAll()
        UserDefaults.standard.set(captureHistory, forKey: SettingsKey.history)
        rebuildMenu()
        log("History cleared")
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        recognitionLanguage = code
        UserDefaults.standard.set(code, forKey: SettingsKey.language)
        rebuildMenu()
        log("Recognition language set to \(code)")
    }

    @objc private func toggleDetectColumns() {
        detectColumns.toggle()
        UserDefaults.standard.set(detectColumns, forKey: SettingsKey.detectColumns)
        rebuildMenu()
        log("Detect columns: \(detectColumns)")
    }

    @objc private func togglePreview() {
        showCopyPreview.toggle()
        UserDefaults.standard.set(showCopyPreview, forKey: SettingsKey.showPreview)
        rebuildMenu()
        log("Show copy preview: \(showCopyPreview)")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                log("Launch at login disabled")
            } else {
                try SMAppService.mainApp.register()
                log("Launch at login enabled")
            }
        } catch {
            log("ERROR: Launch at login toggle failed: \(error)")
            NSSound.beep()
        }
        rebuildMenu()
    }

    private func addToHistory(_ text: String) {
        // Deduplicate: remove identical earlier capture, insert at front
        captureHistory.removeAll { $0 == text }
        captureHistory.insert(text, at: 0)
        if captureHistory.count > maxHistoryItems {
            captureHistory = Array(captureHistory.prefix(maxHistoryItems))
        }
        UserDefaults.standard.set(captureHistory, forKey: SettingsKey.history)
        rebuildMenu()
    }

    private func playSuccessSound() {
        if let sound = successSound {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        log("Setting up global hotkeys...")
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

            DispatchQueue.main.async {
                log("Global hotkey pressed: id=\(hotkeyID.id)")
                if hotkeyID.id == 1 {
                    AppDelegate.shared?.captureWithLineBreaks()
                } else if hotkeyID.id == 2 {
                    AppDelegate.shared?.captureWithoutLineBreaks()
                } else if hotkeyID.id == 3 {
                    AppDelegate.shared?.captureAndSpeak()
                } else if hotkeyID.id == 4 {
                    AppDelegate.shared?.captureAndAppend()
                }
            }
            return noErr
        }

        let installResult = InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, nil)
        log("InstallEventHandler result: \(installResult)")

        var hotkey1 = EventHotKeyID(signature: OSType(0x4558), id: 1)
        let reg1 = RegisterEventHotKey(UInt32(kVK_ANSI_7), UInt32(shiftKey | cmdKey), hotkey1, GetApplicationEventTarget(), 0, &hotkeyRef1)
        log("RegisterEventHotKey ⇧⌘7 result: \(reg1)")

        var hotkey2 = EventHotKeyID(signature: OSType(0x4558), id: 2)
        let reg2 = RegisterEventHotKey(UInt32(kVK_ANSI_8), UInt32(shiftKey | cmdKey), hotkey2, GetApplicationEventTarget(), 0, &hotkeyRef2)
        log("RegisterEventHotKey ⇧⌘8 result: \(reg2)")

        var hotkey3 = EventHotKeyID(signature: OSType(0x4558), id: 3)
        let reg3 = RegisterEventHotKey(UInt32(kVK_ANSI_9), UInt32(shiftKey | cmdKey), hotkey3, GetApplicationEventTarget(), 0, &hotkeyRef3)
        log("RegisterEventHotKey ⇧⌘9 result: \(reg3)")

        var hotkey4 = EventHotKeyID(signature: OSType(0x4558), id: 4)
        let reg4 = RegisterEventHotKey(UInt32(kVK_ANSI_0), UInt32(shiftKey | cmdKey), hotkey4, GetApplicationEventTarget(), 0, &hotkeyRef4)
        log("RegisterEventHotKey ⇧⌘0 result: \(reg4)")
    }

    // MARK: - Capture Actions

    @objc func captureWithLineBreaks() {
        log("captureWithLineBreaks called")
        keepLineBreaks = true
        speakAfterCapture = false
        appendToClipboard = false
        showOverlay()
    }

    @objc func captureWithoutLineBreaks() {
        log("captureWithoutLineBreaks called")
        keepLineBreaks = false
        speakAfterCapture = false
        appendToClipboard = false
        showOverlay()
    }

    @objc func captureAndSpeak() {
        log("captureAndSpeak called")
        keepLineBreaks = true
        speakAfterCapture = true
        appendToClipboard = false
        showOverlay()
    }

    @objc func captureAndAppend() {
        log("captureAndAppend called")
        keepLineBreaks = true
        speakAfterCapture = false
        appendToClipboard = true
        showOverlay()
    }

    @objc func stopSpeaking() {
        log("stopSpeaking called")
        speechService.stop()
    }

    // MARK: - Permissions

    /// Returns true if Screen Recording permission is granted.
    /// Otherwise triggers the system prompt and shows an explanatory alert.
    private func ensureScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        log("Screen capture permission missing - showing alert")

        // Trigger the system prompt (adds the app to the Screen Recording list)
        CGRequestScreenCaptureAccess()

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = """
        Text Extractor can't capture text without Screen Recording permission.

        Enable "Text Extractor" in System Settings → Privacy & Security → \
        Screen & System Audio Recording, then relaunch the app.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
        return false
    }

    // MARK: - Overlay

    private func showOverlay() {
        log("showOverlay called")
        guard ensureScreenCapturePermission() else { return }
        guard let screen = NSScreen.main else {
            log("No main screen!")
            return
        }
        log("Screen: \(screen.frame)")

        // Create fresh window each time to avoid state issues
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.onSelection = { [weak self] rect in
            self?.handleSelection(rect, screen: screen)
        }
        view.onCancel = { [weak self] in
            self?.dismissOverlay()
        }

        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)

        // Store references
        overlayWindow = window
        overlayView = view
        log("Overlay window created and shown: \(window.frame)")
    }

    private func dismissOverlay() {
        log("dismissOverlay called")
        NSCursor.pop()  // Restore cursor stack
        overlayWindow?.enableCursorRects()
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
    }

    private func handleSelection(_ rect: NSRect, screen: NSScreen) {
        log("handleSelection called with rect: \(rect)")
        // Dismiss overlay first
        dismissOverlay()

        // Capture immediately (overlay is already hidden)
        captureAndOCR(rect: rect, screen: screen)
    }

    // MARK: - Screen Capture & OCR

    private enum CaptureError: Error {
        case noDisplayFound
    }

    private func captureAndOCR(rect: NSRect, screen: NSScreen) {
        log("captureAndOCR called with rect: \(rect)")

        // Convert from AppKit coordinates (origin bottom-left) to Quartz (origin top-left)
        let screenHeight = screen.frame.height
        let captureRect = CGRect(
            x: rect.origin.x,
            y: screenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
        log("Capture rect (Quartz coords): \(captureRect)")

        Task {
            do {
                let cgImage = try await captureImage(captureRect, screen: screen)
                processImage(cgImage)
            } catch {
                log("ERROR: Screen capture failed: \(error)")
                NSSound.beep()
            }
        }
    }

    /// Capture a region of the screen using ScreenCaptureKit.
    /// (CGWindowListCreateImage is deprecated and silently returns
    /// wallpaper-only images when Screen Recording permission is missing.)
    private func captureImage(_ captureRect: CGRect, screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the display containing the selection
        guard let display = content.displays.first(where: { $0.frame.intersects(captureRect) })
                ?? content.displays.first else {
            throw CaptureError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        // sourceRect is in points, relative to the display's own origin
        config.sourceRect = CGRect(
            x: captureRect.origin.x - display.frame.origin.x,
            y: captureRect.origin.y - display.frame.origin.y,
            width: captureRect.width,
            height: captureRect.height
        )
        config.width = Int(captureRect.width * scale)
        config.height = Int(captureRect.height * scale)
        config.showsCursor = false
        config.captureResolution = .best

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private func processImage(_ cgImage: CGImage) {
        log("Image captured: \(cgImage.width)x\(cgImage.height)")

        // Save debug image
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: "/tmp/textextractor_capture.png"))
            log("Debug image saved to /tmp/textextractor_capture.png")
        }

        // Perform OCR + barcode detection in one pass
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if recognitionLanguage == "auto" {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = [recognitionLanguage]
        }

        let barcodeRequest = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request, barcodeRequest])
        } catch {
            log("ERROR: Vision request failed: \(error)")
            NSSound.beep()
            return
        }

        let barcodePayloads = (barcodeRequest.results ?? [])
            .compactMap { $0.payloadStringValue }
        if !barcodePayloads.isEmpty {
            log("Found \(barcodePayloads.count) barcode(s)/QR code(s)")
        }

        let observations = request.results ?? []
        guard !observations.isEmpty || !barcodePayloads.isEmpty else {
            log("ERROR: No text or barcodes found")
            NSSound.beep()
            if showCopyPreview {
                showResultHUD("", title: "No text found")
            }
            return
        }
        log("OCR found \(observations.count) observations")

        // Extract text.
        // Vision can split one visual line into several observations and
        // returns them in no guaranteed order, so sorting by Y alone
        // scrambles the output. Instead: group observations into visual
        // lines by vertical overlap, then sort left-to-right within a line.
        let items: [(box: CGRect, text: String)] = observations.compactMap { obs in
            guard let str = obs.topCandidates(1).first?.string else { return nil }
            return (obs.boundingBox, str)
        }
        // Top to bottom (normalized coordinates have a bottom-left origin)
        .sorted { $0.0.midY > $1.0.midY }

        var lines: [(rect: CGRect, items: [(box: CGRect, text: String)])] = []
        for item in items {
            if let i = lines.indices.last {
                let ref = lines[i].rect
                let overlap = min(item.box.maxY, ref.maxY) - max(item.box.minY, ref.minY)
                // Same visual line if it vertically overlaps >50% of the shorter box
                if overlap > min(item.box.height, ref.height) * 0.5 {
                    lines[i].items.append(item)
                    lines[i].rect = lines[i].rect.union(item.box)
                    continue
                }
            }
            lines.append((item.box, [item]))
        }

        let textLines = lines.map { line -> String in
            let sorted = line.items.sorted { $0.box.minX < $1.box.minX }
            guard detectColumns, sorted.count > 1 else {
                return sorted.map(\.text).joined(separator: " ")
            }
            // Column detection: a horizontal gap wider than one character
            // height (~2 characters) marks a column boundary → emit a tab
            var result = sorted[0].text
            for i in 1..<sorted.count {
                let gap = sorted[i].box.minX - sorted[i - 1].box.maxX
                let charHeight = max(sorted[i].box.height, sorted[i - 1].box.height)
                result += (gap > charHeight ? "\t" : " ") + sorted[i].text
            }
            return result
        }
        var text = textLines.joined(separator: keepLineBreaks ? "\n" : " ")
        log("Grouped \(observations.count) observations into \(textLines.count) lines")

        // Include QR/barcode payloads (payload only when nothing else was found)
        if !barcodePayloads.isEmpty {
            let payloadText = barcodePayloads.joined(separator: "\n")
            text = text.isEmpty ? payloadText : text + "\n" + payloadText
        }

        guard !text.isEmpty else {
            log("ERROR: Extracted text is empty")
            NSSound.beep()
            if showCopyPreview {
                showResultHUD("", title: "No text found")
            }
            return
        }
        log("Extracted text (\(text.count) chars): \(text.prefix(100))...")

        // Copy (or append) to clipboard and play sound immediately
        let pasteboard = NSPasteboard.general
        let hudTitle: String
        if appendToClipboard,
           let existing = pasteboard.string(forType: .string),
           !existing.isEmpty {
            pasteboard.clearContents()
            pasteboard.setString(existing + "\n\n" + text, forType: .string)
            hudTitle = "Appended ✓"
        } else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            hudTitle = "Copied ✓"
        }

        playSuccessSound()
        addToHistory(text)
        log("Text copied to clipboard, sound played")

        if showCopyPreview {
            showResultHUD(text, title: hudTitle)
        }

        // Speak the text if requested
        if speakAfterCapture {
            log("Speaking text...")
            speechService.speak(text)
        }
    }

    // MARK: - Result HUD

    /// Small floating "Copied ✓" panel with a preview of the captured text.
    /// Non-activating, click-through, auto-dismisses after a short delay.
    private func showResultHUD(_ text: String, title: String) {
        hudDismissTask?.cancel()
        hudWindow?.orderOut(nil)
        hudWindow = nil

        guard let screen = NSScreen.main else { return }

        // Build content
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor

        let preview = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .prefix(3)
            .joined(separator: "\n")
        let previewLabel = NSTextField(wrappingLabelWithString: String(preview.prefix(200)))
        previewLabel.font = .systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor
        previewLabel.maximumNumberOfLines = 3
        previewLabel.preferredMaxLayoutWidth = 300

        let stack = NSStackView(views: text.isEmpty ? [titleLabel] : [titleLabel, previewLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true
        effectView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: effectView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
        ])

        let size = effectView.fittingSize
        // Top-right corner, just below the menu bar
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - size.width - 16,
            y: screen.visibleFrame.maxY - size.height - 16
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = effectView
        panel.orderFrontRegardless()
        hudWindow = panel

        // Fade out and dismiss
        let dismiss = DispatchWorkItem { [weak self] in
            guard let panel = self?.hudWindow else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
                if self?.hudWindow === panel { self?.hudWindow = nil }
            })
        }
        hudDismissTask = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: dismiss)
    }
}

// MARK: - Selection Overlay View

final class SelectionOverlayView: NSView {
    var onSelection: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var mouseLocation: NSPoint?
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupTrackingArea()
            // Hide the system cursor
            CGDisplayHideCursor(CGMainDisplayID())
            // Get initial mouse location
            mouseLocation = window?.mouseLocationOutsideOfEventStream
            needsDisplay = true
        }
    }

    func cleanup() {
        // Show the system cursor again
        CGDisplayShowCursor(CGMainDisplayID())
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseMoved(with event: NSEvent) {
        mouseLocation = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            cleanup()
            onCancel?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        log("mouseDown at: \(event.locationInWindow)")
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        mouseLocation = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        mouseLocation = currentPoint
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        log("mouseUp at: \(event.locationInWindow)")
        cleanup()  // Restore cursor before processing

        guard let start = startPoint, let current = currentPoint else {
            log("mouseUp: no start/current point, cancelling")
            onCancel?()
            return
        }

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        log("Selection rect: \(rect)")

        if rect.width > 5 && rect.height > 5 {
            log("Valid selection, calling onSelection")
            onSelection?(rect)
        } else {
            log("Selection too small, cancelling")
            onCancel?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dark overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()

        // Draw crosshair at current mouse location
        if let mouse = mouseLocation {
            let crosshairSize: CGFloat = 10
            let crosshairPath = NSBezierPath()

            // Horizontal line
            crosshairPath.move(to: NSPoint(x: mouse.x - crosshairSize, y: mouse.y))
            crosshairPath.line(to: NSPoint(x: mouse.x + crosshairSize, y: mouse.y))

            // Vertical line
            crosshairPath.move(to: NSPoint(x: mouse.x, y: mouse.y - crosshairSize))
            crosshairPath.line(to: NSPoint(x: mouse.x, y: mouse.y + crosshairSize))

            NSColor.white.setStroke()
            crosshairPath.lineWidth = 1.5
            crosshairPath.stroke()
        }

        // Selection rectangle
        guard let start = startPoint, let current = currentPoint else { return }

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )

        guard rect.width > 0 && rect.height > 0 else { return }

        // Clear the selection area
        NSColor.clear.setFill()
        rect.fill(using: .copy)

        // Draw border
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()

        // Size label
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let labelPoint = NSPoint(x: rect.maxX - size.width - 4, y: rect.minY - size.height - 4)

        // Label background
        let labelRect = NSRect(x: labelPoint.x - 2, y: labelPoint.y - 2, width: size.width + 4, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()

        text.draw(at: labelPoint, withAttributes: attrs)
    }
}
