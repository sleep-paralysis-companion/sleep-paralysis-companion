import Observation

@MainActor
@Observable
final class AppModel {
    private(set) var path: [AppRoute] = []
    private(set) var isReady = false

    let environment: AppEnvironment
    let accessPolicy: AccessPolicy

    private let logger: any PrivacySafeLogging
    @ObservationIgnored
    private var activationTask: Task<Void, Never>?

    init(
        environment: AppEnvironment,
        accessPolicy: AccessPolicy,
        logger: any PrivacySafeLogging
    ) {
        self.environment = environment
        self.accessPolicy = accessPolicy
        self.logger = logger
    }

    func activate() {
        activationTask?.cancel()
        activationTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self else {
                return
            }
            isReady = true
            logger.record(.appActivated, category: .lifecycle)
        }
    }

    func deactivate() {
        activationTask?.cancel()
        activationTask = nil
        logger.record(.appDeactivated, category: .lifecycle)
    }

    func send(_ intent: Intent) {
        switch intent {
        case .showFoundationDetails:
            path.append(.foundationDetails)
            logger.record(.routeChanged, category: .navigation)
        case let .setPath(newPath):
            path = newPath
            logger.record(.routeChanged, category: .navigation)
        }
    }

    enum Intent: Sendable {
        case showFoundationDetails
        case setPath([AppRoute])
    }
}
