//
//  LookAwaySetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

#if os(iOS)
    import UIKit
#endif

struct LookAwaySetupView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var previewWindowController: NSWindowController?
    @ObservedObject var cameraAccess = CameraAccessService.shared
    @State private var failedCameraAccess = false

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            VStack(spacing: 16) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Look Away Reminder")
                    .font(.system(size: 28, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

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
                                val: settingsManager.settings.lookAwayTimer.intervalSeconds / 60,
                                range: Range(bounds: 5...60, step: 5)
                            )
                        },
                        set: { newValue in
                            settingsManager.settings.lookAwayTimer.intervalSeconds =
                                (newValue.val ?? 20) * 60
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
                    enabled: Binding(
                        get: { settingsManager.settings.lookAwayTimer.enabled },
                        set: { settingsManager.settings.lookAwayTimer.enabled = $0 }
                    ),
                    type: "Look away",
                    previewFunc: showPreviewWindow
                )
                Toggle(
                    "Enable enforcement mode",
                    isOn: Binding(
                        get: { settingsManager.settings.enforcementMode },
                        set: { settingsManager.settings.enforcementMode = $0 }
                    )
                )
                .onChange(
                    of: settingsManager.settings.enforcementMode,
                ) { newMode in
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
            #if failedCameraAccess
                Text(
                    "Camera access denied. Please enable camera access in System Settings if you want to use enforcement mode."
                )
            #endif
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private func showPreviewWindow() {
        guard let screen = NSScreen.main else { return }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true

        let contentView = LookAwayReminderView(
            countdownSeconds: settingsManager.settings.lookAwayCountdownSeconds
        ) {
            [weak window] in
            window?.close()
        }

        window.contentView = NSHostingView(rootView: contentView)
        window.makeFirstResponder(window.contentView)

        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)

        previewWindowController = windowController
    }
}

#Preview("Look Away Setup View") {
    LookAwaySetupView(settingsManager: SettingsManager.shared)
}
