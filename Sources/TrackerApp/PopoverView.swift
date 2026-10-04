import AppKit
import SwiftUI
import TrackerCore

struct PopoverView: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Picker("Tracking", selection: Binding(
                get: { model.mode },
                set: { model.setMode($0) }
            )) {
                Text("Automatic").tag(TrackingMode.automatic)
                Text("Keep working").tag(TrackingMode.keepWorking)
                Text("Keep idle").tag(TrackingMode.keepIdle)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            Text(modeCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            Divider()

            if model.history.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.history.prefix(30)), id: \.day) { day in
                            HStack {
                                Text(day.day, format: .dateTime.day().month().weekday(.abbreviated))
                                Spacer()
                                Text(TrackerModel.format(day.total))
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Divider()

            menuButton("Dashboard") {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            menuButton("Add manual entry") {
                openWindow(id: "add-work")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            menuButton("Settings") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            menuButton("Quit") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: 280)
        .padding(.bottom, 4)
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        HoverMenuButton(title: title, action: action)
    }

    private var modeCaption: String {
        switch model.mode {
        case .automatic:
            return "Camera decides when the clock runs."
        case .keepWorking:
            return "Counting with the camera off — e.g. working on another device."
        case .keepIdle:
            return "Paused with the camera off — presence is ignored."
        }
    }

    private var statusBadge: some View {
        switch model.mode {
        case .keepWorking:
            return Label("Working · manual", systemImage: "bolt.fill")
        case .keepIdle:
            return Label("Paused · manual", systemImage: "pause.circle.fill")
        case .automatic:
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
}

private struct HoverMenuButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovered ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
