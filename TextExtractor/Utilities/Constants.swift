import Foundation
import Carbon
import AppKit

enum Constants {
    static let appName = "Text Extractor"
    static let bundleIdentifier = "com.textextractor.app"

    // Default keyboard shortcuts
    enum DefaultShortcuts {
        static let captureText = (keyCode: kVK_ANSI_2, modifiers: NSEvent.ModifierFlags([.command, .shift]))
        static let captureNoLineBreaks = (keyCode: kVK_ANSI_3, modifiers: NSEvent.ModifierFlags([.command, .shift]))
        static let captureWithSpeech = (keyCode: kVK_ANSI_4, modifiers: NSEvent.ModifierFlags([.command, .shift]))
        static let capturePrevious = (keyCode: kVK_ANSI_5, modifiers: NSEvent.ModifierFlags([.command, .shift]))
        static let captureQRCode = (keyCode: kVK_ANSI_6, modifiers: NSEvent.ModifierFlags([.command, .shift]))
    }

    // Supported languages
    enum SupportedLanguages {
        static let all: [(code: String, name: String)] = [
            ("en-US", "English"),
            ("es-ES", "Spanish"),
            ("fr-FR", "French"),
            ("de-DE", "German"),
            ("pt-BR", "Portuguese"),
            ("it-IT", "Italian"),
            ("zh-Hans", "Chinese (Simplified)"),
            ("zh-Hant", "Chinese (Traditional)"),
            ("ja-JP", "Japanese"),
            ("ko-KR", "Korean"),
            ("uk-UA", "Ukrainian"),
            ("ru-RU", "Russian"),
            ("vi-VN", "Vietnamese"),
            ("th-TH", "Thai"),
            ("tr-TR", "Turkish"),
            ("pl-PL", "Polish"),
            ("nl-NL", "Dutch"),
            ("sv-SE", "Swedish"),
            ("da-DK", "Danish"),
            ("nb-NO", "Norwegian"),
            ("cs-CZ", "Czech"),
            ("id-ID", "Indonesian"),
            ("ms-MY", "Malay"),
            ("ro-RO", "Romanian")
        ]
    }

    // UserDefaults keys
    enum UserDefaultsKeys {
        static let keepLineBreaks = "keepLineBreaks"
        static let additiveClipboard = "additiveClipboard"
        static let playCaptureSound = "playCaptureSound"
        static let showNotifications = "showNotifications"
        static let autoOpenLinks = "autoOpenLinks"
        static let speechRate = "speechRate"
        static let recognitionLanguages = "recognitionLanguages"
        static let customWords = "customWords"
        static let launchAtLogin = "launchAtLogin"
    }

    // OCR settings
    enum OCRSettings {
        static let minimumTextHeight: Float = 0.01
        static let recognitionLevel: Int = 1 // 0 = fast, 1 = accurate
        static let usesLanguageCorrection = true
    }

    // Speech settings
    enum SpeechSettings {
        static let defaultRate: Float = 0.5
        static let minRate: Float = 0.0
        static let maxRate: Float = 1.0
    }
}
