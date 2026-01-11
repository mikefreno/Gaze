//
//  PostureSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

struct PostureSetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    @State private var previewWindowController: NSWindowController?

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            VStack(spacing: 16) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Posture Reminder")
                    .font(.system(size: 28, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

            // Vertically centered content
            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 12) {
                    Button(action: {
                        // Using properly URL-encoded text fragment
                        // Points to key findings about sitting posture and behavior relationship with LBP
                        if let url = URL(
                            string:
                                "https://pubmed.ncbi.nlm.nih.gov/40111906/#:~:text=For%20studies%20exploring%20sitting%20posture%2C%20seven%20found%20a%20relationship%20with%20LBP.%20Regarding%20studies%20on%20sitting%20behavior%2C%20only%20one%20showed%20no%20relationship%20between%20LBP%20prevalence"
                        ) {
                            #if os(iOS)
                                UIApplication.shared.open(url)
                            #elseif os(macOS)
                                NSWorkspace.shared.open(url)
                            #endif
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                    }.buttonStyle(.plain)
                    Text(
                        "Regular posture checks help prevent back and neck pain from prolonged sitting"
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 20) {
                    Toggle("Enable Posture Reminders", isOn: $enabled)
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
                                    ), in: 15...60, step: 5)

                                Text("\(intervalMinutes) min")
                                    .frame(width: 60, alignment: .trailing)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                if enabled {
                    Text(
                        "You will be subtly reminded every \(intervalMinutes) minutes to check your posture"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                    Text(
                        "Posture reminders are currently disabled."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // Preview button
                Button(action: {
                    showPreviewWindow()
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
                }
                .buttonStyle(.plain)
                .glassEffectIfAvailable(GlassStyle.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: 10))
            }

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

        let contentView = PostureReminderView(sizePercentage: 10.0) { [weak window] in
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

#Preview("Posture Setup - Enabled") {
    PostureSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(30)
    )
}

#Preview("Posture Setup - Disabled") {
    PostureSetupView(
        enabled: .constant(false),
        intervalMinutes: .constant(30)
    )
}
