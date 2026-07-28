import Foundation

nonisolated struct LocalStoreLocation: Sendable {
    private let namespace: String

    init(namespace: String) {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        if !namespace.isEmpty,
           namespace.count <= 64,
           namespace.unicodeScalars.allSatisfy(allowed.contains)
        {
            self.namespace = namespace
        } else {
            self.namespace = "primary"
        }
    }

    func databaseURL() throws -> URL {
        let manager = FileManager.default
        let applicationSupport = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport
            .appendingPathComponent("SleepParalysisCompanion", isDirectory: true)
            .appendingPathComponent(namespace, isDirectory: true)
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("local.sqlite", isDirectory: false)
    }
}
