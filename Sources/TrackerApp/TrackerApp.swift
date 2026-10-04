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

        Window("Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(model)
        }
        .defaultSize(width: 1200, height: 760)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 380, height: 320)

        Window("Add Manual Entry", id: "add-work") {
            AddManualWorkView()
                .environmentObject(model)
        }
        .defaultSize(width: 360, height: 240)
    }

    private var iconName: String {
        switch model.mode {
        case .keepWorking: return "bolt.fill"
        case .keepIdle: return "pause.circle.fill"
        case .automatic:
            switch model.state {
            case .idle: return "person.slash"
            case .active: return "person.fill"
            case .grace: return "person.fill.questionmark"
            }
        }
    }
}
