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
    @State private var previewWindowController: NSWindowController?
    var cameraAccess = CameraAccessService.shared
    @State private var failedCameraAccess = false

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "eye.fill", title: "Look Away Reminder", color: .accentColor)

            Spacer()

            VStack(spacing: 30) {
                InfoBox(
                    text: "Suggested: 20-20-20 rule",
                    url: "https://journals.co.za/doi/abs/10.4102/aveh.v79i1.554#:~:text=the 20/20/20 rule induces significant changes in dry eye symptoms and tear film and some limited changes for ocular surface integrity."
                )

                SliderSection(
                    intervalSettings: Binding(
                        get: {
                            RangeChoice(
                                val: settingsManager.settings.lookAwayTimer.intervalSeconds / 60,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.lookAwayTimer.intervalSeconds = (newValue.val ?? 20) * 60
                        }
                    ),
                    countdownSettings: Binding(
                        get: {
                            RangeChoice(
                                val: settingsManager.settings.lookAwayCountdownSeconds,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.lookAwayCountdownSeconds = newValue.val ?? 20
                        }
                    ),
                    enabled: $settingsManager.settings.lookAwayTimer.enabled,
                    type: "Look away",
                    previewFunc: showPreviewWindow
                )
                
                Toggle("Enable enforcement mode", isOn: $settingsManager.settings.enforcementMode)
                    .onChange(of: settingsManager.settings.enforcementMode) { _, newMode in
                        if newMode && !cameraAccess.isCameraAuthorized {
                            Task {
                                do {
                                    try await cameraAccess.requestCameraAccess()
                                } catch {
                                    failedCameraAccess = true
                                    settingsManager.settings.enforcementMode = false
                                }
                            }
                        }
                    }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private func showPreviewWindow() {
        guard let screen = NSScreen.main else { return }
        previewWindowController = PreviewWindowHelper.showPreview(
            on: screen,
            content: LookAwayReminderView(countdownSeconds: settingsManager.settings.lookAwayCountdownSeconds) { [weak previewWindowController] in
                previewWindowController?.window?.close()
            }
        )
    }
}

#Preview("Look Away Setup View") {
    LookAwaySetupView(settingsManager: SettingsManager.shared)
}
