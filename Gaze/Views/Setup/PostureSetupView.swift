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
    @State private var previewWindowController: NSWindowController?

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "figure.stand", title: "Posture Reminder", color: .orange)

            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://pubmed.ncbi.nlm.nih.gov/40111906/#:~:text=For%20studies%20exploring%20sitting%20posture%2C%20seven%20found%20a%20relationship%20with%20LBP.%20Regarding%20studies%20on%20sitting%20behavior%2C%20only%20one%20showed%20no%20relationship%20between%20LBP%20prevalence") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Regular posture checks help prevent back and neck pain from prolonged sitting")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                SliderSection(
                    intervalSettings: Binding(
                        get: {
                            RangeChoice(
                                val: settingsManager.settings.postureTimer.intervalSeconds / 60,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.postureTimer.intervalSeconds = (newValue.val ?? 30) * 60
                        }
                    ),
                    countdownSettings: nil,
                    enabled: $settingsManager.settings.postureTimer.enabled,
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
        previewWindowController = PreviewWindowHelper.showPreview(
            on: screen,
            content: PostureReminderView(sizePercentage: settingsManager.settings.subtleReminderSize.percentage) { [weak previewWindowController] in
                previewWindowController?.window?.close()
            }
        )
    }
}

#Preview("Posture Setup") {
    PostureSetupView(settingsManager: SettingsManager.shared)
}
