import Foundation
import Combine

final class AppSettings: ObservableObject {

    // MARK: - Singleton

    static let shared = AppSettings()

    // MARK: - Published Properties

    @Published var keepLineBreaks: Bool {
        didSet {
            UserDefaults.standard.set(keepLineBreaks, forKey: Constants.UserDefaultsKeys.keepLineBreaks)
        }
    }

    @Published var additiveClipboard: Bool {
        didSet {
            UserDefaults.standard.set(additiveClipboard, forKey: Constants.UserDefaultsKeys.additiveClipboard)
        }
    }

    @Published var playCaptureSound: Bool {
        didSet {
            UserDefaults.standard.set(playCaptureSound, forKey: Constants.UserDefaultsKeys.playCaptureSound)
        }
    }

    @Published var showNotifications: Bool {
        didSet {
            UserDefaults.standard.set(showNotifications, forKey: Constants.UserDefaultsKeys.showNotifications)
        }
    }

    @Published var autoOpenLinks: Bool {
        didSet {
            UserDefaults.standard.set(autoOpenLinks, forKey: Constants.UserDefaultsKeys.autoOpenLinks)
        }
    }

    @Published var speechRate: Float {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: Constants.UserDefaultsKeys.speechRate)
        }
    }

    @Published var recognitionLanguages: [String] {
        didSet {
            UserDefaults.standard.set(recognitionLanguages, forKey: Constants.UserDefaultsKeys.recognitionLanguages)
        }
    }

    @Published var customWords: [String] {
        didSet {
            UserDefaults.standard.set(customWords, forKey: Constants.UserDefaultsKeys.customWords)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Constants.UserDefaultsKeys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults
        defaults.register(defaults: [
            Constants.UserDefaultsKeys.keepLineBreaks: true,
            Constants.UserDefaultsKeys.additiveClipboard: false,
            Constants.UserDefaultsKeys.playCaptureSound: true,
            Constants.UserDefaultsKeys.showNotifications: true,
            Constants.UserDefaultsKeys.autoOpenLinks: false,
            Constants.UserDefaultsKeys.speechRate: Constants.SpeechSettings.defaultRate,
            Constants.UserDefaultsKeys.recognitionLanguages: ["en-US"],
            Constants.UserDefaultsKeys.customWords: [String](),
            Constants.UserDefaultsKeys.launchAtLogin: false
        ])

        // Load saved values
        self.keepLineBreaks = defaults.bool(forKey: Constants.UserDefaultsKeys.keepLineBreaks)
        self.additiveClipboard = defaults.bool(forKey: Constants.UserDefaultsKeys.additiveClipboard)
        self.playCaptureSound = defaults.bool(forKey: Constants.UserDefaultsKeys.playCaptureSound)
        self.showNotifications = defaults.bool(forKey: Constants.UserDefaultsKeys.showNotifications)
        self.autoOpenLinks = defaults.bool(forKey: Constants.UserDefaultsKeys.autoOpenLinks)
        self.speechRate = defaults.float(forKey: Constants.UserDefaultsKeys.speechRate)
        self.recognitionLanguages = defaults.stringArray(forKey: Constants.UserDefaultsKeys.recognitionLanguages) ?? ["en-US"]
        self.customWords = defaults.stringArray(forKey: Constants.UserDefaultsKeys.customWords) ?? []
        self.launchAtLogin = defaults.bool(forKey: Constants.UserDefaultsKeys.launchAtLogin)
    }

    // MARK: - Methods

    func resetToDefaults() {
        keepLineBreaks = true
        additiveClipboard = false
        playCaptureSound = true
        showNotifications = true
        autoOpenLinks = false
        speechRate = Constants.SpeechSettings.defaultRate
        recognitionLanguages = ["en-US"]
        customWords = []
        launchAtLogin = false
    }

    private func updateLaunchAtLogin() {
        // Use SMAppService for modern macOS launch at login
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}

import ServiceManagement
