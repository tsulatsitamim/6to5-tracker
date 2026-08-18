import Foundation

public protocol SessionRecording: AnyObject {
    func startSegment(at date: Date)
    func endSegment(at date: Date)
}
