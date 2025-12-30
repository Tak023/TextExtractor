import AppKit
import CoreGraphics
import Carbon

// MARK: - CGRect Extensions

extension CGRect {
    /// Normalize rect to have positive width and height
    var normalized: CGRect {
        var rect = self

        if rect.width < 0 {
            rect.origin.x += rect.width
            rect.size.width = -rect.width
        }

        if rect.height < 0 {
            rect.origin.y += rect.height
            rect.size.height = -rect.height
        }

        return rect
    }

    /// Convert from screen coordinates (origin at bottom-left) to display coordinates (origin at top-left)
    func flippedForScreen() -> CGRect {
        guard let mainScreen = NSScreen.main else { return self }
        let screenHeight = mainScreen.frame.height
        return CGRect(
            x: origin.x,
            y: screenHeight - origin.y - height,
            width: width,
            height: height
        )
    }
}

// MARK: - NSScreen Extensions

extension NSScreen {
    /// Get the combined frame of all screens
    static var combinedFrame: CGRect {
        screens.reduce(.zero) { result, screen in
            result.union(screen.frame)
        }
    }

    /// Get screen containing a point
    static func screen(containing point: NSPoint) -> NSScreen? {
        screens.first { screen in
            screen.frame.contains(point)
        }
    }
}

// MARK: - NSImage Extensions

extension NSImage {
    /// Convert NSImage to CGImage
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

// MARK: - CGImage Extensions

extension CGImage {
    /// Create NSImage from CGImage
    var nsImage: NSImage {
        NSImage(cgImage: self, size: NSSize(width: width, height: height))
    }
}

// MARK: - String Extensions

extension String {
    /// Remove extra whitespace and normalize line breaks
    func normalizedWhitespace() -> String {
        // Replace multiple spaces with single space
        let singleSpaced = self.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        // Normalize line breaks
        return singleSpaced.replacingOccurrences(of: "\r\n", with: "\n")
    }

    /// Remove all line breaks
    func withoutLineBreaks() -> String {
        self.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - NSEvent.ModifierFlags Extensions

extension NSEvent.ModifierFlags {
    /// Convert to Carbon modifier flags for RegisterEventHotKey
    /// Carbon uses different bit positions than NSEvent.ModifierFlags
    var carbonFlags: UInt32 {
        var carbon: UInt32 = 0

        // Carbon modifier flag constants
        // cmdKey = 256 (0x100), shiftKey = 512 (0x200), optionKey = 2048 (0x800), controlKey = 4096 (0x1000)
        if contains(.command) { carbon |= UInt32(cmdKey) }       // 0x100
        if contains(.shift) { carbon |= UInt32(shiftKey) }       // 0x200
        if contains(.option) { carbon |= UInt32(optionKey) }     // 0x800
        if contains(.control) { carbon |= UInt32(controlKey) }   // 0x1000

        return carbon
    }
}

// MARK: - Collection Extensions

extension Collection {
    /// Safe subscript that returns nil for out-of-bounds indices
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
