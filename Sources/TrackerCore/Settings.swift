import Foundation

public enum Settings {
    public static let defaultSampleInterval: TimeInterval = 5
    public static let defaultGracePeriod: TimeInterval = 120
    public static let defaultCameraUnavailableCountsAsPresent = true
    public static let defaultFaceSizeThreshold: Double = 0.15
    public static let defaultBodySizeThreshold: Double = 0.15
    public static let defaultShowThumbnail = true

    public static let sampleIntervalKey = "sampleInterval"
    public static let gracePeriodKey = "gracePeriod"
    public static let cameraUnavailableCountsAsPresentKey = "cameraUnavailableCountsAsPresent"
    public static let faceSizeThresholdKey = "faceSizeThreshold"
    public static let bodySizeThresholdKey = "bodySizeThreshold"
    public static let showThumbnailKey = "showThumbnail"
}
