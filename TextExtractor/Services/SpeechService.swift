import AVFoundation
import AppKit

final class SpeechService: NSObject {

    // MARK: - Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods

    func speak(_ text: String, rate: Float? = nil) {
        // Stop any current speech
        stop()

        let utterance = AVSpeechUtterance(string: text)

        // Set rate
        let speechRate = rate ?? AppSettings.shared.speechRate
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRate

        // Set voice based on system language
        if let voice = getPreferredVoice() {
            utterance.voice = voice
        }

        // Configure utterance
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }

    var isPaused: Bool {
        synthesizer.isPaused
    }

    var isCurrentlySpeaking: Bool {
        synthesizer.isSpeaking
    }

    // MARK: - Voice Selection

    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
    }

    func getVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.starts(with: language.prefix(2))
        }
    }

    private func getPreferredVoice() -> AVSpeechSynthesisVoice? {
        // Try to get system default voice
        let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"

        // Get all voices for the language
        let voices = getVoices(for: systemLanguage)

        // Prefer enhanced/premium voices
        let enhancedVoice = voices.first { voice in
            voice.quality == .enhanced
        }

        return enhancedVoice ?? voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Rate Conversion

    static func convertRateToDisplay(_ rate: Float) -> String {
        let displayRate = rate * 2 // Convert 0-1 to 0-2x
        return String(format: "%.1fx", displayRate)
    }

    static func displayRates() -> [(value: Float, label: String)] {
        [
            (0.25, "0.5x"),
            (0.5, "1.0x"),
            (0.75, "1.5x"),
            (1.0, "2.0x")
        ]
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
