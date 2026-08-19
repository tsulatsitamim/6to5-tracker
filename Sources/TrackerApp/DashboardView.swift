import SwiftUI
import AppKit
import TrackerCore

extension Notification.Name {
    static let dashboardFullScreenChanged = Notification.Name("dashboardFullScreenChanged")
}

final class DashboardWindowController: NSObject, NSWindowDelegate {
    static let shared = DashboardWindowController()

    private(set) var isFullScreen = false
    private weak var window: NSWindow?
    private var savedFrame: NSRect = .zero
    private var savedMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]

    func attach(to window: NSWindow) {
        self.window = window
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.delegate = self
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        toggle()
        return false
    }

    func toggle() {
        guard let window else { return }
        if isFullScreen {
            window.styleMask = savedMask
            window.level = .normal
            window.setFrame(savedFrame, display: true)
            NSApp.presentationOptions = []
            isFullScreen = false
        } else {
            savedFrame = window.frame
            savedMask = window.styleMask
            let frame = window.screen?.frame ?? savedFrame
            window.styleMask = [.borderless]
            window.level = .screenSaver
            window.setFrame(frame, display: true)
            NSApp.presentationOptions = [.hideMenuBar, .hideDock]
            isFullScreen = true
        }
        NotificationCenter.default.post(name: .dashboardFullScreenChanged, object: nil)
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct DashboardView: View {
    @EnvironmentObject private var model: TrackerModel
    @AppStorage(Settings.showThumbnailKey) private var showThumbnail = Settings.defaultShowThumbnail
    @State private var isFullScreen = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let rowTopH = h * 0.6
            let rowBottomH = h * 0.4
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.11),
                        Color(red: 0.03, green: 0.04, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    metricCell("TODAY", value: model.todayElapsed,
                               width: w, height: rowTopH, numberFactor: 0.38)
                    hSeparator
                    HStack(spacing: 0) {
                        metricCell("THIS WEEK", value: model.weekElapsed,
                                   width: w / 2, height: rowBottomH, numberFactor: 0.28)
                        vSeparator
                        metricCell("SITTING", value: model.sittingElapsed,
                                   width: w / 2, height: rowBottomH, numberFactor: 0.28, accent: true)
                    }
                }
                VStack {
                    HStack(alignment: .top) {
                        if showThumbnail {
                            cameraThumbnail
                        }
                        Spacer()
                        if isFullScreen {
                            Button(action: { DashboardWindowController.shared.toggle() }) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .frame(width: 34, height: 34)
                                    .background(Color.white.opacity(0.10))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .background(WindowAccessor { window in
            DashboardWindowController.shared.attach(to: window)
        })
        .onReceive(NotificationCenter.default.publisher(for: .dashboardFullScreenChanged)) { _ in
            isFullScreen = DashboardWindowController.shared.isFullScreen
        }
    }

    private var hSeparator: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
    }

    private var vSeparator: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1)
    }

    @ViewBuilder
    private var cameraThumbnail: some View {
        let thumbW: CGFloat = 180
        let thumbH: CGFloat = 120
        if let image = model.lastCapturedImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbW, height: thumbH)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 1.0, green: 0.3, blue: 0.3)).frame(width: 6, height: 6)
                        Text("LIVE").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Capsule())
                    .padding(6)
                }
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .frame(width: thumbW, height: thumbH)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Waiting")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
        }
    }

    private func metricCell(
        _ label: String,
        value: TimeInterval,
        width: CGFloat,
        height: CGFloat,
        numberFactor: CGFloat,
        accent: Bool = false
    ) -> some View {
        let minDim = min(width, height)
        let numberSize = minDim * numberFactor
        let labelSize = max(minDim * 0.045, 14)
        return VStack(spacing: minDim * 0.03) {
            Spacer(minLength: 0)
            Text(TrackerModel.format(value))
                .font(.system(size: numberSize, weight: .heavy, design: .rounded))
                .foregroundStyle(accent ? Color(red: 0.45, green: 0.70, blue: 1.0) : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(label)
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(labelSize * 0.25)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
    }
}