import AppKit

final class ClipboardService {

    // MARK: - Properties

    private let pasteboard = NSPasteboard.general
    private var clipboardHistory: [String] = []
    private let maxHistorySize = 50
    private let historySeparator = "\n\n---\n\n"

    // MARK: - Public Methods

    func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func appendToClipboard(_ text: String) {
        // Get current clipboard content
        let currentContent = pasteboard.string(forType: .string) ?? ""

        // Append new text with separator
        let newContent: String
        if currentContent.isEmpty {
            newContent = text
        } else {
            newContent = currentContent + historySeparator + text
        }

        // Update clipboard
        pasteboard.clearContents()
        pasteboard.setString(newContent, forType: .string)

        // Add to history
        addToHistory(text)
    }

    func getClipboardContent() -> String? {
        pasteboard.string(forType: .string)
    }

    func clearClipboard() {
        pasteboard.clearContents()
    }

    // MARK: - History Management

    func addToHistory(_ text: String) {
        // Add to beginning of history
        clipboardHistory.insert(text, at: 0)

        // Trim if needed
        if clipboardHistory.count > maxHistorySize {
            clipboardHistory = Array(clipboardHistory.prefix(maxHistorySize))
        }

        // Persist history
        saveHistory()
    }

    func getHistory() -> [String] {
        clipboardHistory
    }

    func clearHistory() {
        clipboardHistory.removeAll()
        saveHistory()
    }

    func getHistoryItem(at index: Int) -> String? {
        guard index >= 0 && index < clipboardHistory.count else { return nil }
        return clipboardHistory[index]
    }

    // MARK: - Persistence

    private let historyKey = "clipboardHistory"

    init() {
        loadHistory()
    }

    private func loadHistory() {
        if let history = UserDefaults.standard.stringArray(forKey: historyKey) {
            clipboardHistory = history
        }
    }

    private func saveHistory() {
        UserDefaults.standard.set(clipboardHistory, forKey: historyKey)
    }

    // MARK: - Rich Content

    func copyRichText(_ text: String, html: String? = nil) {
        pasteboard.clearContents()

        // Set plain text
        pasteboard.setString(text, forType: .string)

        // Set HTML if provided
        if let html = html {
            pasteboard.setString(html, forType: .html)
        }
    }

    func copyImage(_ image: NSImage) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func hasContent() -> Bool {
        pasteboard.string(forType: .string) != nil
    }
}
