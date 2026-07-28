import SwiftUI

@main
struct SleepParalysisCompanionApp: App {
    @State private var model = AppCompositionRoot.makeModel()

    var body: some Scene {
        WindowGroup {
            AppRootView(model: model)
        }
    }
}
