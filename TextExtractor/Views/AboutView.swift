import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // App Name
            Text("Text Extractor")
                .font(.title)
                .fontWeight(.bold)

            // Version
            Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Description
            Text("Capture text from anywhere on your screen using advanced OCR technology.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.horizontal, 40)

            // Features
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "doc.text.viewfinder", text: "OCR Text Recognition")
                FeatureRow(icon: "qrcode.viewfinder", text: "QR Code & Barcode Scanning")
                FeatureRow(icon: "speaker.wave.2", text: "Text-to-Speech")
                FeatureRow(icon: "globe", text: "Multi-language Support")
            }

            Spacer()

            // Copyright
            Text("2024 Text Extractor. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 350, height: 380)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }
}
