import Foundation

struct PublicConfigurationValues: Equatable, Sendable {
    var publicAPIBaseURL: URL?
    var allowedHosts: Set<String>
    var productionHosts: Set<String>

    static let empty = PublicConfigurationValues(
        publicAPIBaseURL: nil,
        allowedHosts: [],
        productionHosts: []
    )
}

enum ConfigurationResult: Equatable, Sendable {
    case ready(AppConfiguration)
    case unavailable(SafeDiagnostic)
}

struct AppConfiguration: Equatable, Sendable, ExternalResourceResolving {
    let environment: AppEnvironment
    private let publicAPIBaseURL: URL?

    static func resolve(
        environment: AppEnvironment,
        values: PublicConfigurationValues
    ) -> ConfigurationResult {
        guard let url = values.publicAPIBaseURL else {
            return .ready(AppConfiguration(environment: environment, publicAPIBaseURL: nil))
        }

        guard let host = url.host(percentEncoded: false)?.lowercased() else {
            return .unavailable(SafeDiagnostic(code: .configurationUnavailable))
        }

        let isNonProduction = environment != .production
        let productionHosts = values.productionHosts.map { $0.lowercased() }
        let allowedHosts = values.allowedHosts.map { $0.lowercased() }
        if isNonProduction {
            if productionHosts.contains(host) {
                return .unavailable(SafeDiagnostic(code: .productionResourceRejected))
            }

            if !allowedHosts.contains(host) {
                return .unavailable(SafeDiagnostic(code: .configurationUnavailable))
            }
        }

        guard url.scheme == "https" else {
            return .unavailable(SafeDiagnostic(code: .configurationUnavailable))
        }

        return .ready(AppConfiguration(environment: environment, publicAPIBaseURL: url))
    }

    func url(for resource: ExternalResource) -> URL? {
        switch resource {
        case .publicAPI:
            publicAPIBaseURL
        }
    }
}

struct BundlePublicConfigurationLoader {
    func load(from bundle: Bundle) -> PublicConfigurationValues {
        let endpointString = bundle.object(forInfoDictionaryKey: "SPCPublicAPIBaseURL") as? String
        let endpoint = endpointString.flatMap { value in
            value.isEmpty ? nil : URL(string: value)
        }

        return PublicConfigurationValues(
            publicAPIBaseURL: endpoint,
            allowedHosts: hostSet(
                from: bundle.object(forInfoDictionaryKey: "SPCAllowedAPIHosts") as? String
            ),
            productionHosts: hostSet(
                from: bundle.object(forInfoDictionaryKey: "SPCProductionAPIHosts") as? String
            )
        )
    }

    private func hostSet(from commaSeparatedValue: String?) -> Set<String> {
        Set(
            (commaSeparatedValue ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }
}
