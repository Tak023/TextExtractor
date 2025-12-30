import Foundation
import CoreGraphics

struct CaptureResult: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let text: String
    let captureRect: CodableRect
    let mode: CaptureResultMode
    let language: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        captureRect: CGRect,
        mode: CaptureResultMode,
        language: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.captureRect = CodableRect(rect: captureRect)
        self.mode = mode
        self.language = language
    }

    var rect: CGRect {
        captureRect.rect
    }
}

enum CaptureResultMode: String, Codable {
    case text
    case textWithSpeech
    case qrCode
    case barcode
}

struct CodableRect: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
