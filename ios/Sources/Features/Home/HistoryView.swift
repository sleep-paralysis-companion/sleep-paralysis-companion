import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.checkIns.isEmpty {
                ContentUnavailableView {
                    Label("No history yet", systemImage: "clock")
                } description: {
                    Text("Optional check-ins appear here only after you submit them.")
                } actions: {
                    Button("Add check-in") { model.open(.morningCheckIn) }
                }
            } else {
                List {
                    Section {
                        ForEach(model.checkIns, id: \.id) { value in
                            Button {
                                model.selectCheckIn(value)
                            } label: {
                                HStack {
                                    Image(systemName: value.occurrence == .yes ? "moon.stars.fill" : "moon.zzz.fill")
                                        .foregroundStyle(value.occurrence == .yes ? Color.indigo : Color.cyan)
                                    VStack(alignment: .leading) {
                                        Text(value.occurrence == .yes ? "Episode reported" : "No episode reported")
                                            .font(.headline)
                                        Text(value.reportedForLocalDate)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .foregroundStyle(.primary)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    model.deleteCheckIn(value)
                                }
                            }
                        }
                    } footer: {
                        Text("History is descriptive and never presents a diagnosis, clinical score, prediction, or risk interpretation.")
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
