import SwiftUI
import TrackerCore

struct PopoverView: View {
    @EnvironmentObject private var model: TrackerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.formattedToday)
                        .font(.title2)
                        .monospacedDigit()
                }
                Spacer()
                statusBadge
            }

            Divider()

            if model.history.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
            } else {
                List(Array(model.history.prefix(30)), id: \.day) { day in
                    HStack {
                        Text(day.day, format: .dateTime.day().month().weekday(.abbreviated))
                        Spacer()
                        Text(TrackerModel.format(day.total))
                            .monospacedDigit()
                    }
                }
            }

            Divider()

            HStack {
                SettingsView()
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var statusBadge: some View {
        switch model.state {
        case .idle:
            return Label("Away", systemImage: "person.slash")
        case .active:
            return Label("Working", systemImage: "person.fill")
        case .grace:
            return Label("Away (grace)", systemImage: "person.fill.questionmark")
        }
    }
}
