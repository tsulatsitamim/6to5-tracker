import SwiftUI
import TrackerCore

@MainActor
final class TrackerModel: ObservableObject {
    @Published var state: EngineState = .idle
    @Published var todayElapsed: TimeInterval = 0
    @Published var history: [DaySummary] = []
    @Published var cameraUnavailable = false

    private let store: SessionStore
    private var engine: WorkSessionEngine
    private var uiTimer: Timer?

    var formattedToday: String { Self.format(todayElapsed) }

    init() {
        store = SessionStore()

        engine = WorkSessionEngine(
            detector: PresenceDetector(),
            recorder: store,
            sampleInterval: Self.load(Settings.sampleIntervalKey, Settings.defaultSampleInterval),
            gracePeriod: Self.load(Settings.gracePeriodKey, Settings.defaultGracePeriod),
            cameraUnavailableCountsAsPresent: Self.load(
                Settings.cameraUnavailableCountsAsPresentKey,
                Settings.defaultCameraUnavailableCountsAsPresent
            )
        )
        engine.onStateChange = { [weak self] newState in
            Task { @MainActor in
                self?.state = newState
                self?.refresh()
            }
        }
    }

    func start() {
        refresh()
        engine.start()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.shutdown()
        }
    }

    func refresh() {
        let now = Date()
        let summaries = DayGrouping.summarize(store.allSegments(), now: now)
        history = Array(summaries.reversed())
        let today = Calendar.current.startOfDay(for: now)
        todayElapsed = summaries.first(where: { $0.day == today })?.total ?? 0
    }

    private func shutdown() {
        uiTimer?.invalidate()
        engine.stop()
    }

    private static func load<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    static func format(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
