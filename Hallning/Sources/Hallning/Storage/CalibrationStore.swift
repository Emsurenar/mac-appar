import Foundation

/// One recorded posture: a burst of frames with the same label.
struct CalibrationSample: Codable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case onboarding, feedback
    }

    var id = UUID()
    var label: PostureLabel
    var issue: PostureIssue?
    /// Index of the onboarding prompt, or -1 for feedback.
    var promptIndex: Int
    var vectors: [FeatureVector]
    /// A representative pose, only for drawing the skeleton thumbnail.
    var pose: BodyPose?
    var date = Date()
    var source: Source = .onboarding
}

struct CalibrationFile: Codable {
    var version = 1
    var samples: [CalibrationSample]
}

/// Application Support/Hallning/calibration.json
enum CalibrationStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Hallning", isDirectory: true)
    }

    private static var url: URL { directory.appendingPathComponent("calibration.json") }

    static func load() -> [CalibrationSample] {
        guard let data = try? Data(contentsOf: url),
              let file = try? decoder.decode(CalibrationFile.self, from: data) else { return [] }
        return file.samples
    }

    static func save(_ samples: [CalibrationSample]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(CalibrationFile(samples: samples))
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Posture: could not save calibration: \(error)")
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
