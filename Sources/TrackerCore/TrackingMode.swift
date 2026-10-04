import Foundation

/// How the tracker decides whether work time is being counted.
///
/// `automatic` is the default camera-driven behaviour. The manual modes
/// override the camera entirely so tracking keeps going (or stops) even when
/// no presence signal is available, e.g. when working on another device.
public enum TrackingMode: Equatable, Hashable {
    /// Camera presence detection drives the state machine.
    case automatic
    /// Force the clock to keep counting; the camera is not sampled.
    case keepWorking
    /// Force the clock to stop; the camera is not sampled.
    case keepIdle
}
