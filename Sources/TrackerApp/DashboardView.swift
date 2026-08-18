import SwiftUI
import TrackerCore

struct DashboardView: View {
    @EnvironmentObject private var model: TrackerModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()
                HStack(spacing: 0) {
                    metricCell("TODAY", value: model.todayElapsed, proxy: proxy)
                    separator
                    metricCell("THIS WEEK", value: model.weekElapsed, proxy: proxy)
                    separator
                    metricCell("SITTING", value: model.sittingElapsed, proxy: proxy, accent: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1)
    }

    private func metricCell(
        _ label: String,
        value: TimeInterval,
        proxy: GeometryProxy,
        accent: Bool = false
    ) -> some View {
        let minDim = min(proxy.size.width, proxy.size.height)
        let numberSize = minDim * 0.15
        let labelSize = max(minDim * 0.03, 12)
        return VStack(spacing: minDim * 0.04) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
