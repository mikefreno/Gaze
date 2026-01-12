import SwiftUI

struct SliderSection: View {
    @Binding var intervalMinutes: Int
    @Binding var countdownSeconds: Int
    @Binding var enabled: Bool

    let intervalRange: ClosedRange<Int>
    let countdownRange: ClosedRange<Int>?
    let type: String
    let previewFunc: () -> Void
    let reminderText: String

    init(
        intervalMinutes: Binding<Int>,
        countdownSeconds: Binding<Int>,
        intervalRange: ClosedRange<Int>,
        countdownRange: ClosedRange<Int>? = nil,
        enabled: Binding<Bool>,
        type: String,
        reminderText: String,
        previewFunc: @escaping () -> Void
    ) {
        self._intervalMinutes = intervalMinutes
        self._countdownSeconds = countdownSeconds
        self.intervalRange = intervalRange
        self.countdownRange = countdownRange
        self._enabled = enabled
        self.type = type
        self.reminderText = reminderText
        self.previewFunc = previewFunc
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Enable \(type.titleCase) Reminders", isOn: $enabled)
                .font(.headline)

            if enabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remind me every:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(intervalMinutes) },
                                set: { intervalMinutes = Int($0) }
                            ),
                            in:
                                Double(intervalRange.lowerBound)...Double(intervalRange.upperBound),
                            step: 5.0)
                        Text("\(intervalMinutes) min")
                            .frame(width: 60, alignment: .trailing)
                            .monospacedDigit()
                    }

                    if let range = countdownRange {
                        Text("Look away for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(countdownSeconds) },
                                    set: { countdownSeconds = Int($0) }
                                ), in: Double(range.lowerBound)...Double(range.upperBound),
                                step: 5.0)
                            Text("\(countdownSeconds) sec")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }.padding()
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

        if enabled {
            Text(
                reminderText
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        } else {
            Text(
                "\(type) reminders are currently disabled."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Button(action: {
            previewFunc()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundColor(.white)
                Text("Preview Reminder")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 10)
        )
    }
}
