import AppKit
import AVFoundation

final class SoundService {

    // MARK: - Sound Types

    enum SoundType {
        case capture
        case success
        case error

        var systemSound: NSSound.Name? {
            switch self {
            case .capture:
                return NSSound.Name("Tink")
            case .success:
                return NSSound.Name("Glass")
            case .error:
                return NSSound.Name("Basso")
            }
        }
    }

    // MARK: - Properties

    private var sounds: [SoundType: NSSound] = [:]

    // MARK: - Initialization

    init() {
        preloadSounds()
    }

    // MARK: - Preload Sounds

    private func preloadSounds() {
        for type in [SoundType.capture, .success, .error] {
            if let soundName = type.systemSound,
               let sound = NSSound(named: soundName) {
                sounds[type] = sound
            }
        }
    }

    // MARK: - Play Sounds

    func play(_ type: SoundType) {
        guard AppSettings.shared.playCaptureSound else { return }

        if let sound = sounds[type] {
            sound.stop()
            sound.play()
        } else if let soundName = type.systemSound,
                  let sound = NSSound(named: soundName) {
            sound.play()
        }
    }

    func playCapture() {
        play(.capture)
    }

    func playSuccess() {
        play(.success)
    }

    func playError() {
        play(.error)
    }

    // MARK: - System Screenshot Sound

    func playScreenshotSound() {
        // Play the system screenshot sound
        // This is the same sound macOS uses when taking a screenshot
        if let soundURL = Bundle.main.url(forResource: "screenshot", withExtension: "aiff") {
            if let sound = NSSound(contentsOf: soundURL, byReference: true) {
                sound.play()
                return
            }
        }

        // Fallback to system sound
        playCapture()
    }
}
