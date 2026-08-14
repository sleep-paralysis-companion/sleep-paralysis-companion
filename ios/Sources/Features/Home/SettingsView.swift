import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        MeProfileView(model: model)
    }
}
