import AppKit
import AudioToolbox
import Carbon
import CoreGraphics
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
    private var successSound: NSSound?

    // Hotkey references
    private var hotkeyRef1: EventHotKeyRef?
    private var hotkeyRef2: EventHotKeyRef?
    private static var shared: AppDelegate?

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("App launching...")
        AppDelegate.shared = self
        setupStatusItem()
        setupHotkeys()
        setupLocalMonitor()

        // Preload success sound (Glass has a nice chime-like quality)
        if let sound = NSSound(contentsOfFile: "/System/Library/Sounds/Glass.aiff", byReference: true) {
            successSound = sound
            log("Success sound loaded (Glass)")
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

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Text (⇧⌘7)", action: #selector(captureWithLineBreaks), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Text No Breaks (⇧⌘8)", action: #selector(captureWithoutLineBreaks), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
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
    }

    // MARK: - Capture Actions

    @objc func captureWithLineBreaks() {
        log("captureWithLineBreaks called")
        keepLineBreaks = true
        showOverlay()
    }

    @objc func captureWithoutLineBreaks() {
        log("captureWithoutLineBreaks called")
        keepLineBreaks = false
        showOverlay()
    }

    // MARK: - Overlay

    private func showOverlay() {
        log("showOverlay called")
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

        // Small delay to ensure overlay is gone
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.captureAndOCR(rect: rect, screen: screen)
        }
    }

    // MARK: - Screen Capture & OCR

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

        // Capture screen
        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            log("ERROR: CGWindowListCreateImage returned nil")
            NSSound.beep()
            return
        }
        log("Image captured: \(cgImage.width)x\(cgImage.height)")

        // Save debug image
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: "/tmp/textextractor_capture.png"))
            log("Debug image saved to /tmp/textextractor_capture.png")
        }

        // Perform OCR
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            NSSound.beep()
            return
        }

        guard let observations = request.results, !observations.isEmpty else {
            log("ERROR: No text observations found")
            NSSound.beep()
            return
        }
        log("OCR found \(observations.count) observations")

        // Extract text
        let text: String
        if keepLineBreaks {
            let lines = observations
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { $0.topCandidates(1).first?.string }
            text = lines.joined(separator: "\n")
        } else {
            let lines = observations
                .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
                .compactMap { $0.topCandidates(1).first?.string }
            text = lines.joined(separator: " ")
        }

        guard !text.isEmpty else {
            log("ERROR: Extracted text is empty")
            NSSound.beep()
            return
        }
        log("Extracted text (\(text.count) chars): \(text.prefix(100))...")

        // Copy to clipboard and play sound immediately
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Play success sound immediately after copy
        if let sound = successSound {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }

        log("Text copied to clipboard, sound played")
    }
}

// MARK: - Selection Overlay View

final class SelectionOverlayView: NSView {
    var onSelection: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
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
            // Hide system cursor and use crosshair
            NSCursor.crosshair.push()
            window?.disableCursorRects()
            window?.invalidateCursorRects(for: self)
        }
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        }
    }

    override func mouseDown(with event: NSEvent) {
        log("mouseDown at: \(event.locationInWindow)")
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        log("mouseUp at: \(event.locationInWindow)")
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
