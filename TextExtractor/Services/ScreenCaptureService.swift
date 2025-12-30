import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {

    // MARK: - Properties

    private var availableContent: SCShareableContent?

    // MARK: - Permission Check

    func hasScreenCapturePermission() -> Bool {
        // Try to capture a 1x1 pixel region to check permission
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        let image = CGWindowListCreateImage(
            testRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming]
        )
        return image != nil
    }

    func requestScreenCapturePermission() {
        // Opening System Preferences to Screen Recording section
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    // MARK: - Screen Capture

    func captureRegion(_ rect: CGRect) -> CGImage? {
        // Normalize the rect
        let normalizedRect = rect.normalized

        // Capture using CGWindowListCreateImage
        let image = CGWindowListCreateImage(
            normalizedRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        )

        return image
    }

    func captureEntireScreen(displayID: CGDirectDisplayID = CGMainDisplayID()) -> CGImage? {
        CGDisplayCreateImage(displayID)
    }

    func captureWindow(windowID: CGWindowID) -> CGImage? {
        CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    // MARK: - Multi-Monitor Support

    func getAllDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)

        return displays
    }

    func getDisplayBounds(displayID: CGDirectDisplayID) -> CGRect {
        CGDisplayBounds(displayID)
    }

    func getCombinedDisplayBounds() -> CGRect {
        let displays = getAllDisplays()
        var combinedBounds = CGRect.zero

        for display in displays {
            let bounds = getDisplayBounds(displayID: display)
            combinedBounds = combinedBounds.union(bounds)
        }

        return combinedBounds
    }

    func getDisplayContaining(point: CGPoint) -> CGDirectDisplayID? {
        let displays = getAllDisplays()

        for display in displays {
            let bounds = getDisplayBounds(displayID: display)
            if bounds.contains(point) {
                return display
            }
        }

        return nil
    }

    // MARK: - High Resolution Capture

    func captureRegionHighRes(_ rect: CGRect) -> CGImage? {
        // For Retina displays, capture at native resolution
        guard let display = getDisplayContaining(point: rect.origin) else {
            return captureRegion(rect)
        }

        let scale = NSScreen.screens
            .first { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == display }?
            .backingScaleFactor ?? 1.0

        // Capture at screen resolution
        let image = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.boundsIgnoreFraming, .bestResolution]
        )

        return image
    }
}
