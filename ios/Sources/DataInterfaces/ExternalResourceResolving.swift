import Foundation

nonisolated enum ExternalResource: Hashable, Sendable {
    case publicAPI
}

nonisolated protocol ExternalResourceResolving: Sendable {
    func url(for resource: ExternalResource) -> URL?
}
