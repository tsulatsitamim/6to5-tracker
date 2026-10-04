import SwiftUI
import TrackerCore

struct SettingsView: View {
    @AppStorage(Settings.sampleIntervalKey) private var sampleInterval = Settings.defaultSampleInterval
    @AppStorage(Settings.gracePeriodKey) private var gracePeriod = Settings.defaultGracePeriod
    @AppStorage(Settings.cameraUnavailableCountsAsPresentKey) private var cameraPolicy = Settings.defaultCameraUnavailableCountsAsPresent
    @AppStorage(Settings.faceSizeThresholdKey) private var faceThreshold = Settings.defaultFaceSizeThreshold
    @AppStorage(Settings.bodySizeThresholdKey) private var bodyThreshold = Settings.defaultBodySizeThreshold
    @AppStorage(Settings.showThumbnailKey) private var showThumbnail = Settings.defaultShowThumbnail

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
            Toggle("Show camera thumbnail on dashboard", isOn: $showThumbnail)

            Section("Detection thresholds") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Face size")
                        Spacer()
                        Text(String(format: "%.2f", faceThreshold)).monospacedDigit()
                    }
                    Slider(value: $faceThreshold, in: 0.05...0.5, step: 0.01)
                    Text("Lower = detects faces farther away. Raise to stop at distance.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Body size")
                        Spacer()
                        Text(String(format: "%.2f", bodyThreshold)).monospacedDigit()
                    }
                    Slider(value: $bodyThreshold, in: 0.05...0.5, step: 0.01)
                    Text("Raise so a person standing far away is not counted (body fallback).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Text("Sample interval & grace period apply after restart. Thresholds apply immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Manual modes (Keep working / Keep idle) reset to Automatic when the app restarts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .formStyle(.grouped)
    }
}
