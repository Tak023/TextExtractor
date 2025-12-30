import UserNotifications
import AppKit

final class NotificationService: NSObject {

    // MARK: - Properties

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    override init() {
        super.init()
        requestAuthorization()
        notificationCenter.delegate = self
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }

    // MARK: - Show Notifications

    func showNotification(title: String, body: String, identifier: String = UUID().uuidString) {
        guard AppSettings.shared.showNotifications else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil // We handle sound separately

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }

    func showSuccessNotification(text: String) {
        let preview = String(text.prefix(100))
        let suffix = text.count > 100 ? "..." : ""
        showNotification(
            title: "Text Captured",
            body: preview + suffix
        )
    }

    func showErrorNotification(message: String) {
        showNotification(
            title: "Capture Failed",
            body: message
        )
    }

    func showQRCodeNotification(payload: String) {
        let preview = String(payload.prefix(100))
        let suffix = payload.count > 100 ? "..." : ""
        showNotification(
            title: "QR Code Detected",
            body: preview + suffix
        )
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed
        completionHandler()
    }
}
