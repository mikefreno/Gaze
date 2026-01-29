//
//  LookAwaySetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

struct LookAwaySetupView: View {
    @Bindable var settingsManager: SettingsManager
    var cameraAccess = CameraAccessService.shared
    @State private var failedCameraAccess = false

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "eye.fill", title: "Look Away Reminder", color: .accentColor)

            Spacer()

            VStack(spacing: 30) {
                InfoBox(
                    text: "Suggested: 20-20-20 rule",
                    url:
                        "https://journals.co.za/doi/abs/10.4102/aveh.v79i1.554#:~:text=the 20/20/20 rule induces significant changes in dry eye symptoms and tear film and some limited changes for ocular surface integrity."
                )

                SliderSection(
                    intervalSettings: Binding(
                        get: {
                            RangeChoice(
                                value: settingsManager.settings.lookAwayIntervalMinutes,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.lookAwayIntervalMinutes = newValue.value ?? 30
                        }
                    ),
                    countdownSettings: nil,
                    enabled: $settingsManager.settings.lookAwayEnabled,
                    type: "Look Away",
                    previewFunc: previewLookAway
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private func previewLookAway() {
        guard let screen = NSScreen.main else { return }
        let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
        let lookAwayIntervalMinutes = settingsManager.settings.lookAwayIntervalMinutes
        PreviewWindowHelper.showPreview(on: screen) { dismiss in
            LookAwayReminderView(countdownSeconds: lookAwayIntervalMinutes * 60, onDismiss: dismiss)
        }
    }
}

#Preview("Look Away Setup View") {
    LookAwaySetupView(settingsManager: SettingsManager.shared)
}
