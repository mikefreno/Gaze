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
    @Binding var enabled: Bool
    @Binding var intervalSettings: RangeChoice
    @Binding var countdownSettings: RangeChoice
    @State private var previewWindowController: NSWindowController?

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

            // Vertically centered content
            Spacer()

            VStack(spacing: 30) {
                // InfoBox with link functionality
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(
                            string:
                                "https://journals.co.za/doi/abs/10.4102/aveh.v79i1.554#:~:text=the 20/20/20 rule induces significant changes in dry eye symptoms and tear film and some limited changes for ocular surface integrity."
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
                    Text("Suggested: 20-20-20 rule")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding()
                .glassEffectIfAvailable(
                    GlassStyle.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                SliderSection(
                    intervalSettings: $intervalSettings,
                    countdownSettings: $countdownSettings,
                    enabled: $enabled,
                    type: "Look away",
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

        let contentView = LookAwayReminderView(countdownSeconds: countdownSettings.val ?? 20) {
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

//TODO: add this back
/*#Preview("Look Away Setup View") {*/
/*LookAwaySetupView(*/
/*enabled: .constant(true),*/
/*intervalMinutes: .constant(20),*/
/*countdownSeconds: .constant(20)*/
/*)*/
/*}*/
