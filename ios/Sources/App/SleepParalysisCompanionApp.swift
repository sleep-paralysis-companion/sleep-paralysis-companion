import SwiftUI

@main
struct SleepParalysisCompanionApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = AppCompositionRoot.makeModel()

    var body: some Scene {
        WindowGroup {
            AppRootView(model: model)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.activate()
            case .background:
                model.deactivate()
            case .inactive:
                break
            @unknown default:
                model.deactivate()
            }
        }
    }
}
