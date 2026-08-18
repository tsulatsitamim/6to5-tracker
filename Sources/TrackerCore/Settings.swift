import Foundation

public enum Settings {
    public static let defaultSampleInterval: TimeInterval = 5
    public static let defaultGracePeriod: TimeInterval = 120
    public static let defaultCameraUnavailableCountsAsPresent = true

    public static let sampleIntervalKey = "sampleInterval"
    public static let gracePeriodKey = "gracePeriod"
    public static let cameraUnavailableCountsAsPresentKey = "cameraUnavailableCountsAsPresent"
}
