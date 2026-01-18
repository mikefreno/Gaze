//
//  BlinkSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

struct BlinkSetupView: View {
    @Bindable var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "eye.circle", title: "Blink Reminder", color: .green)

            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(
                            string:
                                "https://www.aao.org/eye-health/tips-prevention/computer-usage#:~:text=Humans normally blink about 15 times in one minute. However, studies show that we only blink about 5 to 7 times in a minute while using computers and other digital screen devices."
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(
                        "We blink much less when focusing on screens. Regular blink reminders help prevent dry eyes."
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                }
                .padding()
                .glassEffectIfAvailable(
                    GlassStyle.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 20) {
                    Toggle(
                        "Enable Blink Reminders", isOn: $settingsManager.settings.blinkTimer.enabled
                    )
                    .font(.headline)

                    if settingsManager.settings.blinkTimer.enabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Remind me every:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                Slider(
                                    value: Binding(
                                        get: {
                                            Double(
                                                settingsManager.settings.blinkTimer.intervalSeconds
                                                    / 60)
                                        },
                                        set: {
                                            settingsManager.settings.blinkTimer.intervalSeconds =
                                                Int($0) * 60
                                        }
                                    ),
                                    in: 1...20,
                                    step: 1
                                )

                                Text(
                                    "\(settingsManager.settings.blinkTimer.intervalSeconds / 60) min"
                                )
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                            }
                        }
                    }
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                if settingsManager.settings.blinkTimer.enabled {
                    Text(
                        "You will be subtly reminded every \(settingsManager.settings.blinkTimer.intervalSeconds / 60) minutes to blink"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Blink reminders are currently disabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: showPreviewWindow) {
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private func showPreviewWindow() {
        guard let screen = NSScreen.main else { return }
        let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
        PreviewWindowHelper.showPreview(on: screen) { dismiss in
            BlinkReminderView(sizePercentage: sizePercentage, onDismiss: dismiss)
        }
    }
}

#Preview("Blink Setup") {
    BlinkSetupView(settingsManager: SettingsManager.shared)
}
