import Foundation
import Combine

final class CaptureHistory: ObservableObject {

    // MARK: - Singleton

    static let shared = CaptureHistory()

    // MARK: - Properties

    @Published private(set) var items: [CaptureResult] = []

    private let maxHistorySize = 100
    private let historyKey = "captureHistory"

    // MARK: - Initialization

    private init() {
        loadHistory()
    }

    // MARK: - Public Methods

    func add(_ result: CaptureResult) {
        items.insert(result, at: 0)

        // Trim history if needed
        if items.count > maxHistorySize {
            items = Array(items.prefix(maxHistorySize))
        }

        saveHistory()
    }

    func remove(_ result: CaptureResult) {
        items.removeAll { $0.id == result.id }
        saveHistory()
    }

    func clear() {
        items.removeAll()
        saveHistory()
    }

    func getItem(at index: Int) -> CaptureResult? {
        guard index >= 0 && index < items.count else { return nil }
        return items[index]
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return }

        do {
            items = try JSONDecoder().decode([CaptureResult].self, from: data)
        } catch {
            print("Failed to load capture history: \(error)")
        }
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            print("Failed to save capture history: \(error)")
        }
    }
}
