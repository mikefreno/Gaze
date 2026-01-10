//
//  BlinkSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct BlinkSetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            VStack(spacing: 16) {
                Image(systemName: "eye.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Blink Reminder")
                    .font(.system(size: 28, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

            // Vertically centered content
            Spacer()

            VStack(spacing: 30) {
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(
                            string:
                                "https://www.aao.org/eye-health/tips-prevention/computer-usage#:~:text=Humans normally blink about 15 times in one minute. However, studies show that we only blink about 5 to 7 times in a minute while using computers and other digital screen devices."
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
                        "We blink much less when focusing on screens. Regular blink reminders help prevent dry eyes."
                    )
                    .font(.headline)
                    .foregroundColor(.white)
                }
                .padding()
                .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 20) {
                    Toggle("Enable Blink Reminders", isOn: $enabled)
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
                                    ), in: 1...15, step: 1)

                                Text("\(intervalMinutes) min")
                                    .frame(width: 60, alignment: .trailing)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 12))

                if enabled {
                    Text(
                        "You will be subtly reminded every \(intervalMinutes) minutes to blink"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                    Text(
                        "Blink reminders are currently disabled."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }
}

#Preview("Blink Setup - Enabled") {
    BlinkSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(5)
    )
}

#Preview("Blink Setup - Disabled") {
    BlinkSetupView(
        enabled: .constant(false),
        intervalMinutes: .constant(5)
    )
}
