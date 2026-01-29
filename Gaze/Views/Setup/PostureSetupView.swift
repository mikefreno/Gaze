//
//  PostureSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

struct PostureSetupView: View {
    @Bindable var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "figure.stand", title: "Posture Reminder", color: .orange)

            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(
                            string:
                                "https://pubmed.ncbi.nlm.nih.gov/40111906/#:~:text=For%20studies%20exploring%20sitting%20posture%2C%20seven%20found%20a%20relationship%20with%20LBP.%20Regarding%20studies%20on%20sitting%20behavior%2C%20only%20one%20showed%20no%20relationship%20between%20LBP%20prevalence"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Text(
                        "Regular posture checks help prevent back and neck pain from prolonged sitting"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                }
                .padding()
                .glassEffectIfAvailable(
                    GlassStyle.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                SliderSection(
                    intervalSettings: Binding(
                        get: {
                            RangeChoice(
                                value: settingsManager.settings.postureIntervalMinutes,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.postureIntervalMinutes = newValue.value ?? 30
                        }
                    ),
                    countdownSettings: nil,
                    enabled: $settingsManager.settings.postureEnabled,
                    type: "Posture",
                    previewFunc: showPreviewWindow
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
            PostureReminderView(sizePercentage: sizePercentage, onDismiss: dismiss)
        }
    }
}

#Preview("Posture Setup") {
    PostureSetupView(settingsManager: SettingsManager.shared)
}
