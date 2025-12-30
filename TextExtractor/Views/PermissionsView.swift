import SwiftUI
import AppKit

struct PermissionsView: View {
    @State private var screenCaptureGranted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Permissions Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Text Extractor needs certain permissions to capture text from your screen.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Permission Items
            VStack(spacing: 16) {
                PermissionItem(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required to capture text from your screen",
                    isGranted: screenCaptureGranted,
                    action: openScreenCaptureSettings
                )
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Check Again") {
                    checkPermissions()
                }
                .buttonStyle(.bordered)

                Button("Continue") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!screenCaptureGranted)
            }
        }
        .padding(30)
        .frame(width: 420, height: 350)
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        screenCaptureGranted = checkScreenCapturePermission()
    }

    private func checkScreenCapturePermission() -> Bool {
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return CGWindowListCreateImage(testRect, .optionOnScreenOnly, kCGNullWindowID, []) != nil
    }

    private func openScreenCaptureSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isGranted ? .green : .orange)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action Button
            if !isGranted {
                Button("Open Settings") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
