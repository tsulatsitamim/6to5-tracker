import SwiftUI
import TrackerCore

@main
struct PresenceTrackerApp: App {
    @StateObject private var model: TrackerModel

    init() {
        let model = TrackerModel()
        _model = StateObject(wrappedValue: model)
        NSApplication.shared.setActivationPolicy(.accessory)
        model.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
        } label: {
            Image(systemName: iconName)
            Text(model.formattedToday)
        }
        .menuBarExtraStyle(.window)
    }

    private var iconName: String {
        switch model.state {
        case .idle: return "person.slash"
        case .active: return "person.fill"
        case .grace: return "person.fill.questionmark"
        }
    }
}
