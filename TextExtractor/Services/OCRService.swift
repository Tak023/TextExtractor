import Vision
import AppKit

final class OCRService {

    // MARK: - Errors

    enum OCRError: LocalizedError {
        case imageConversionFailed
        case recognitionFailed(Error)
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Failed to process the image for text recognition."
            case .recognitionFailed(let error):
                return "Text recognition failed: \(error.localizedDescription)"
            case .noTextFound:
                return "No text was found in the selected area."
            }
        }
    }

    // MARK: - Public Methods

    /// Synchronous OCR - runs Vision request and returns result
    /// This avoids async/continuation issues that can cause crashes
    func recognizeTextSync(
        from image: CGImage,
        languages: [String] = ["en-US"],
        keepLineBreaks: Bool = true,
        customWords: [String] = []
    ) -> Result<String, Error> {
        // Create text recognition request
        var recognizedText = ""
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                recognitionError = OCRError.recognitionFailed(error)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                recognitionError = OCRError.noTextFound
                return
            }

            // Extract text directly here to avoid any reference issues
            let sortedObservations = observations.sorted { first, second in
                first.boundingBox.origin.y > second.boundingBox.origin.y
            }

            var lines: [String] = []
            var currentLineY: CGFloat = -1
            var currentLine: [String] = []
            let lineThreshold: CGFloat = 0.02

            for observation in sortedObservations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let y = observation.boundingBox.origin.y

                if currentLineY < 0 {
                    currentLineY = y
                    currentLine.append(candidate.string)
                } else if abs(y - currentLineY) < lineThreshold {
                    currentLine.append(candidate.string)
                } else {
                    if !currentLine.isEmpty {
                        lines.append(currentLine.joined(separator: " "))
                    }
                    currentLineY = y
                    currentLine = [candidate.string]
                }
            }

            if !currentLine.isEmpty {
                lines.append(currentLine.joined(separator: " "))
            }

            if keepLineBreaks {
                recognizedText = lines.joined(separator: "\n")
            } else {
                recognizedText = lines.joined(separator: " ")
            }
        }

        // Configure request
        configureRequest(request, languages: languages, customWords: customWords)

        // Create handler and perform request synchronously
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return .failure(OCRError.recognitionFailed(error))
        }

        if let error = recognitionError {
            return .failure(error)
        }

        if recognizedText.isEmpty {
            return .failure(OCRError.noTextFound)
        }

        return .success(recognizedText)
    }

    func getSupportedLanguages() -> [String] {
        // Return revision-specific supported languages
        let revision = VNRecognizeTextRequestRevision3
        do {
            let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate,
                revision: revision
            )
            return languages
        } catch {
            // Fallback to basic list
            return ["en-US"]
        }
    }

    // MARK: - Private Methods

    private func configureRequest(
        _ request: VNRecognizeTextRequest,
        languages: [String],
        customWords: [String]
    ) {
        // Use accurate recognition
        request.recognitionLevel = .accurate

        // Enable automatic language detection
        request.automaticallyDetectsLanguage = true

        // Set preferred languages
        request.recognitionLanguages = languages

        // Set custom words for domain-specific vocabulary
        if !customWords.isEmpty {
            request.customWords = customWords
        }

        // Use language correction
        request.usesLanguageCorrection = true

        // Set minimum text height (relative to image height)
        request.minimumTextHeight = Constants.OCRSettings.minimumTextHeight
    }

    private func processObservations(
        _ observations: [VNRecognizedTextObservation],
        keepLineBreaks: Bool
    ) -> String {
        // Sort observations by vertical position (top to bottom)
        let sortedObservations = observations.sorted { first, second in
            // Higher Y values are at the top in Vision coordinate system
            first.boundingBox.origin.y > second.boundingBox.origin.y
        }

        var lines: [String] = []
        var currentLineY: CGFloat = -1
        var currentLine: [String] = []
        let lineThreshold: CGFloat = 0.02 // Threshold for considering text on same line

        for observation in sortedObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            let y = observation.boundingBox.origin.y

            if currentLineY < 0 {
                // First observation
                currentLineY = y
                currentLine.append(candidate.string)
            } else if abs(y - currentLineY) < lineThreshold {
                // Same line - add to current line
                currentLine.append(candidate.string)
            } else {
                // New line - save current line and start new one
                if !currentLine.isEmpty {
                    // Sort words in line by X position (left to right)
                    lines.append(currentLine.joined(separator: " "))
                }
                currentLineY = y
                currentLine = [candidate.string]
            }
        }

        // Don't forget the last line
        if !currentLine.isEmpty {
            lines.append(currentLine.joined(separator: " "))
        }

        // Join lines
        if keepLineBreaks {
            return lines.joined(separator: "\n").normalizedWhitespace()
        } else {
            return lines.joined(separator: " ").withoutLineBreaks()
        }
    }
}
