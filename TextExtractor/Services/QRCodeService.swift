import Vision
import AppKit

final class QRCodeService {

    // MARK: - Types

    struct DetectedCode: Identifiable {
        let id = UUID()
        let payload: String
        let type: CodeType
        let boundingBox: CGRect

        enum CodeType: String {
            case qr = "QR Code"
            case aztec = "Aztec"
            case code128 = "Code 128"
            case code39 = "Code 39"
            case code93 = "Code 93"
            case dataMatrix = "Data Matrix"
            case ean8 = "EAN-8"
            case ean13 = "EAN-13"
            case itf14 = "ITF-14"
            case pdf417 = "PDF417"
            case upce = "UPC-E"
            case unknown = "Unknown"

            init(from symbology: VNBarcodeSymbology) {
                switch symbology {
                case .qr:
                    self = .qr
                case .aztec:
                    self = .aztec
                case .code128:
                    self = .code128
                case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
                    self = .code39
                case .code93, .code93i:
                    self = .code93
                case .dataMatrix:
                    self = .dataMatrix
                case .ean8:
                    self = .ean8
                case .ean13:
                    self = .ean13
                case .itf14:
                    self = .itf14
                case .pdf417:
                    self = .pdf417
                case .upce:
                    self = .upce
                default:
                    self = .unknown
                }
            }
        }
    }

    // MARK: - Errors

    enum QRCodeError: LocalizedError {
        case detectionFailed(Error)
        case noCodeFound

        var errorDescription: String? {
            switch self {
            case .detectionFailed(let error):
                return "Code detection failed: \(error.localizedDescription)"
            case .noCodeFound:
                return "No QR code or barcode was found in the selected area."
            }
        }
    }

    // MARK: - Public Methods

    func detectCodes(in image: CGImage) async throws -> [DetectedCode] {
        try await withCheckedThrowingContinuation { continuation in
            performDetection(image: image) { result in
                continuation.resume(with: result)
            }
        }
    }

    func isURL(_ string: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }

        let range = NSRange(string.startIndex..., in: string)
        let matches = detector.matches(in: string, options: [], range: range)

        return matches.first?.range == range
    }

    // MARK: - Private Methods

    private func performDetection(
        image: CGImage,
        completion: @escaping (Result<[DetectedCode], Error>) -> Void
    ) {
        // Create barcode detection request
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                completion(.failure(QRCodeError.detectionFailed(error)))
                return
            }

            guard let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty else {
                completion(.failure(QRCodeError.noCodeFound))
                return
            }

            // Convert observations to DetectedCode
            let codes = observations.compactMap { observation -> DetectedCode? in
                guard let payload = observation.payloadStringValue else { return nil }

                return DetectedCode(
                    payload: payload,
                    type: DetectedCode.CodeType(from: observation.symbology),
                    boundingBox: observation.boundingBox
                )
            }

            if codes.isEmpty {
                completion(.failure(QRCodeError.noCodeFound))
            } else {
                completion(.success(codes))
            }
        }

        // Configure to detect all supported barcode types
        request.symbologies = [
            .qr,
            .aztec,
            .code128,
            .code39,
            .code93,
            .dataMatrix,
            .ean8,
            .ean13,
            .itf14,
            .pdf417,
            .upce
        ]

        // Create handler and perform request
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            completion(.failure(QRCodeError.detectionFailed(error)))
        }
    }
}
