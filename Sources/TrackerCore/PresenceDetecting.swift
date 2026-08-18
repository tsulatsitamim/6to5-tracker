import Foundation

public enum PresenceResult: Equatable {
    case present
    case absent
    case cameraUnavailable
}

public protocol PresenceDetecting {
    func detectPresence() -> PresenceResult
}
