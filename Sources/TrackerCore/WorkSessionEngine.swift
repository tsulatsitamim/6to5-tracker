import Foundation

public final class WorkSessionEngine {
    public var onStateChange: ((EngineState) -> Void)?

    public private(set) var state: EngineState = .idle {
        didSet { if oldValue != state { onStateChange?(state) } }
    }

    private let detector: PresenceDetecting
    private let recorder: SessionRecording
    private let sampleInterval: TimeInterval
    private let gracePeriod: TimeInterval
    private let cameraUnavailableCountsAsPresent: Bool
    private let clock: () -> Date

    private var graceDeadline: Date?
    private var timer: Timer?

    public init(
        detector: PresenceDetecting,
        recorder: SessionRecording,
        sampleInterval: TimeInterval = Settings.defaultSampleInterval,
        gracePeriod: TimeInterval = Settings.defaultGracePeriod,
        cameraUnavailableCountsAsPresent: Bool = Settings.defaultCameraUnavailableCountsAsPresent,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.detector = detector
        self.recorder = recorder
        self.sampleInterval = sampleInterval
        self.gracePeriod = gracePeriod
        self.cameraUnavailableCountsAsPresent = cameraUnavailableCountsAsPresent
        self.clock = clock
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: sampleInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        closeIfNeeded(at: clock())
    }

    private func tick() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = self?.detector.detectPresence() ?? .cameraUnavailable
            DispatchQueue.main.async {
                guard let self else { return }
                self.handle(result: result, at: self.clock())
            }
        }
    }

    public func handle(result: PresenceResult, at date: Date) {
        let isPresent = result == .present
            || (result == .cameraUnavailable && cameraUnavailableCountsAsPresent)

        if isPresent {
            if state == .idle {
                state = .active
                recorder.startSegment(at: date)
            } else if state == .grace {
                state = .active
            }
            graceDeadline = nil
        } else {
            switch state {
            case .idle:
                break
            case .active:
                state = .grace
                graceDeadline = date.addingTimeInterval(gracePeriod)
            case .grace:
                if let deadline = graceDeadline, date >= deadline {
                    state = .idle
                    recorder.endSegment(at: date)
                    graceDeadline = nil
                }
            }
        }
    }

    private func closeIfNeeded(at date: Date) {
        if state == .active || state == .grace {
            state = .idle
            recorder.endSegment(at: date)
        }
        graceDeadline = nil
    }
}
