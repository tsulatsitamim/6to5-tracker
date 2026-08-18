import SwiftUI
import TrackerCore

struct SettingsView: View {
    @AppStorage(Settings.sampleIntervalKey) private var sampleInterval = Settings.defaultSampleInterval
    @AppStorage(Settings.gracePeriodKey) private var gracePeriod = Settings.defaultGracePeriod
    @AppStorage(Settings.cameraUnavailableCountsAsPresentKey) private var cameraPolicy = Settings.defaultCameraUnavailableCountsAsPresent

    var body: some View {
        Form {
            Picker("Check every", selection: $sampleInterval) {
                Text("3 seconds").tag(3.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
                Text("30 seconds").tag(30.0)
            }
            Picker("Grace period", selection: $gracePeriod) {
                Text("30 seconds").tag(30.0)
                Text("1 minute").tag(60.0)
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
            }
            Toggle("Camera busy counts as present", isOn: $cameraPolicy)
            Text("Changes apply after restarting the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .formStyle(.grouped)
    }
}
