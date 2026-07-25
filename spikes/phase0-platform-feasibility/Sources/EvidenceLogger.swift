import Foundation

actor EvidenceLogger {
    static let shared = EvidenceLogger()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    nonisolated var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("phase0-evidence.jsonl")
    }

    func record(_ event: String, details: [String: String] = [:]) {
        let entry = EvidenceEntry(
            timestamp: Date(),
            event: event,
            details: details
        )

        guard let data = try? encoder.encode(entry),
              var line = String(data: data, encoding: .utf8)
        else {
            return
        }

        line.append("\n")
        let payload = Data(line.utf8)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else {
                return
            }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: payload)
        } else {
            try? payload.write(to: fileURL, options: .atomic)
        }
    }
}

private struct EvidenceEntry: Encodable {
    let timestamp: Date
    let event: String
    let details: [String: String]
}

