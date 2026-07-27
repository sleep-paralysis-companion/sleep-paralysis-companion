import Foundation

enum AppEnvironment: String, CaseIterable, Sendable {
    case development
    case staging
    case production

    static var compiled: AppEnvironment {
        #if SPC_ENV_PRODUCTION
            .production
        #elseif SPC_ENV_STAGING
            .staging
        #else
            .development
        #endif
    }
}
