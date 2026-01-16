import SwiftUI

struct SliderSection: View {
    @Binding var intervalSettings: RangeChoice
    @Binding var countdownSettings: RangeChoice
    @Binding var enabled: Bool

    let type: String
    let previewFunc: () -> Void

    init(
        intervalSettings: Binding<RangeChoice>,
        countdownSettings: Binding<RangeChoice>?,
        enabled: Binding<Bool>,
        type: String,
        previewFunc: @escaping () -> Void
    ) {
        self._intervalSettings = intervalSettings
        self._countdownSettings = countdownSettings ?? .constant(RangeChoice(val: nil, range: nil))
        self._enabled = enabled
        self.type = type
        self.previewFunc = previewFunc
    }

    var reminderText: String {
        guard enabled else {
            return "\(type) reminders are currently disabled."
        }
        if countdownSettings.isNil && !intervalSettings.isNil {
            return "You will be reminded every \(intervalSettings.val ?? 0) minutes"
        }
        return
            "You will be \(countdownSettings.isNil ? "subtly" : "") reminded every \(intervalSettings.val ?? 0) minutes for \(countdownSettings.val ?? 0) seconds"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Enable \(type.titleCase) Reminders", isOn: $enabled)
                .font(.headline)

            if enabled && !intervalSettings.isNil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Remind me every:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(intervalSettings.val ?? 0) },
                                set: { intervalSettings.val = Int($0) }
                            ),
                            in:
                                Double(
                                    intervalSettings.range?.bounds.lowerBound ?? 0)...Double(
                                    intervalSettings.range?.bounds.upperBound ?? 100),
                            step: 5.0)
                        Text("\(intervalSettings.val ?? 0) min")
                            .frame(width: 60, alignment: .trailing)
                            .monospacedDigit()
                    }

                    if let range = countdownSettings.range {
                        Text("Look away for:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(countdownSettings.val ?? 0) },
                                    set: { countdownSettings.val = Int($0) }
                                ),
                                in:
                                    Double(
                                        range.bounds.lowerBound)...Double(range.bounds.upperBound),
                                step: 5.0)
                            Text("\(countdownSettings.val ?? 0) sec")
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
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        } else {
            Text(
                "\(type) reminders are currently disabled."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button(action: {
            previewFunc()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(.white)
                Text("Preview Reminder")
                    .font(.headline)
                    .foregroundStyle(.white)
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
