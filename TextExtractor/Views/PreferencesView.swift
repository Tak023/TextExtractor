import SwiftUI

struct PreferencesView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(1)

            LanguagesSettingsView()
                .tabItem {
                    Label("Languages", systemImage: "globe")
                }
                .tag(2)

            CustomWordsSettingsView()
                .tabItem {
                    Label("Custom Words", systemImage: "text.book.closed")
                }
                .tag(3)

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(4)
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Keep line breaks in captured text", isOn: $settings.keepLineBreaks)
                    .help("When enabled, line breaks from the original text will be preserved")

                Toggle("Additive clipboard mode", isOn: $settings.additiveClipboard)
                    .help("When enabled, captured text will be appended to existing clipboard content")
            } header: {
                Text("Text Capture")
            }

            Section {
                Toggle("Play capture sound", isOn: $settings.playCaptureSound)

                Toggle("Show notifications", isOn: $settings.showNotifications)
                    .help("Show notification after successful text capture")

                Toggle("Auto-open detected links", isOn: $settings.autoOpenLinks)
                    .help("Automatically open URLs found in captured text or QR codes")
            } header: {
                Text("Feedback")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speech Rate: \(SpeechService.convertRateToDisplay(settings.speechRate))")

                    Slider(
                        value: $settings.speechRate,
                        in: Constants.SpeechSettings.minRate...Constants.SpeechSettings.maxRate,
                        step: 0.1
                    )
                }
            } header: {
                Text("Text-to-Speech")
            }

            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section {
                ShortcutRow(
                    label: "Capture Text",
                    shortcut: "\u{21E7}\u{2318}7"
                )

                ShortcutRow(
                    label: "Capture Text (No Line Breaks)",
                    shortcut: "\u{21E7}\u{2318}8"
                )
            } header: {
                Text("Global Shortcuts")
            } footer: {
                Text("These shortcuts work system-wide, even when Text Extractor is in the background.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

// MARK: - Languages Settings

struct LanguagesSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var searchText = ""

    var filteredLanguages: [(code: String, name: String)] {
        if searchText.isEmpty {
            return Constants.SupportedLanguages.all
        }
        return Constants.SupportedLanguages.all.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            TextField("Search languages...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()

            // Language list
            List {
                ForEach(filteredLanguages, id: \.code) { language in
                    LanguageRow(
                        language: language,
                        isSelected: settings.recognitionLanguages.contains(language.code)
                    ) {
                        toggleLanguage(language.code)
                    }
                }
            }
            .listStyle(.inset)

            // Footer
            HStack {
                Text("\(settings.recognitionLanguages.count) language(s) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Reset to Default") {
                    settings.recognitionLanguages = ["en-US"]
                }
                .buttonStyle(.link)
            }
            .padding()
        }
    }

    private func toggleLanguage(_ code: String) {
        if settings.recognitionLanguages.contains(code) {
            // Don't allow removing the last language
            if settings.recognitionLanguages.count > 1 {
                settings.recognitionLanguages.removeAll { $0 == code }
            }
        } else {
            settings.recognitionLanguages.append(code)
        }
    }
}

struct LanguageRow: View {
    let language: (code: String, name: String)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(language.name)

            Spacer()

            Text(language.code)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

// MARK: - Custom Words Settings

struct CustomWordsSettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @State private var newWord = ""

    var body: some View {
        VStack(spacing: 0) {
            // Add word field
            HStack {
                TextField("Add custom word...", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addWord()
                    }

                Button("Add") {
                    addWord()
                }
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            // Word list
            if settings.customWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No Custom Words")
                        .font(.headline)

                    Text("Add domain-specific words to improve OCR accuracy for technical terms, product names, or other specialized vocabulary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settings.customWords, id: \.self) { word in
                        HStack {
                            Text(word)
                            Spacer()
                            Button {
                                removeWord(word)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete(perform: deleteWords)
                }
                .listStyle(.inset)
            }

            // Footer
            HStack {
                Text("\(settings.customWords.count) word(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !settings.customWords.isEmpty {
                    Button("Clear All") {
                        settings.customWords.removeAll()
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !settings.customWords.contains(trimmed) else { return }

        settings.customWords.append(trimmed)
        newWord = ""
    }

    private func removeWord(_ word: String) {
        settings.customWords.removeAll { $0 == word }
    }

    private func deleteWords(at offsets: IndexSet) {
        settings.customWords.remove(atOffsets: offsets)
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                PermissionStatusRow(
                    title: "Screen Recording",
                    description: "Required for capturing text from your screen",
                    isGranted: checkScreenCapturePermission()
                ) {
                    openScreenCaptureSettings()
                }
            } header: {
                Text("Permissions")
            }

            Section {
                Button("Reset All Settings to Defaults") {
                    settings.resetToDefaults()
                }
                .foregroundColor(.red)
            } header: {
                Text("Reset")
            }

            Section {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
            } header: {
                Text("App Info")
            }
        }
        .formStyle(.grouped)
    }

    private func checkScreenCapturePermission() -> Bool {
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return CGWindowListCreateImage(testRect, .optionOnScreenOnly, kCGNullWindowID, []) != nil
    }

    private func openScreenCaptureSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}

struct PermissionStatusRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    action()
                }
            }
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
