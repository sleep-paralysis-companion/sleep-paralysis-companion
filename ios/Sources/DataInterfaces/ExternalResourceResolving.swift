import Foundation

enum ExternalResource: Hashable, Sendable {
    case publicAPI
}

protocol ExternalResourceResolving: Sendable {
    func url(for resource: ExternalResource) -> URL?
}
