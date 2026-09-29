import SwiftUI

struct AddManualWorkView: View {
    @EnvironmentObject private var model: TrackerModel
    @Environment(\.dismiss) private var dismiss

    @State private var day = Date()
    @State private var startTime = Calendar.current.date(
        bySettingHour: 9, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var endTime = Calendar.current.date(
        bySettingHour: 10, minute: 0, second: 0, of: Date()
    ) ?? Date()
    @State private var errorMessage: String?

    private var isValidRange: Bool {
        endComponentsAfterStart
    }

    private var endComponentsAfterStart: Bool {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: startTime)
        let end = calendar.dateComponents([.hour, .minute], from: endTime)
        let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
        let endMinutes = (end.hour ?? 0) * 60 + (end.minute ?? 0)
        return endMinutes > startMinutes
    }

    var body: some View {
        Form {
            DatePicker("Date", selection: $day, displayedComponents: .date)
            DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("End time", selection: $endTime, displayedComponents: .hourAndMinute)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("If this overlaps existing work, only the new uncovered time is added to totals.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValidRange)
            }
        }
        .padding(12)
        .formStyle(.grouped)
        .frame(minWidth: 320)
    }

    private func submit() {
        guard isValidRange else {
            errorMessage = "End time must be after start time."
            return
        }
        guard model.addManualWork(day: day, startTime: startTime, endTime: endTime) else {
            errorMessage = "Could not add work entry."
            return
        }
        errorMessage = nil
        dismiss()
    }
}
