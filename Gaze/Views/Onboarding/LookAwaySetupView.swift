//
//  LookAwaySetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

struct LookAwaySetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    @Binding var countdownSeconds: Int

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Look Away Reminder")
                .font(.system(size: 28, weight: .bold))

            // InfoBox with link functionality
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(
                        string: "https://www.healthline.com/health/eye-health/20-20-20-rule")
                    {
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
            .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 20) {
                Toggle("Enable Look Away Reminders", isOn: $enabled)
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
                                ), in: 5...60, step: 5)

                            Text("\(intervalMinutes) min")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }

                        Text("Look away for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(countdownSeconds) },
                                    set: { countdownSeconds = Int($0) }
                                ), in: 10...30, step: 5)

                            Text("\(countdownSeconds) sec")
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
                    "You will be reminded every \(intervalMinutes) minutes to look in the distance for \(countdownSeconds) seconds"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            } else {
                Text(
                    "Look away reminders are currently disabled."
                )
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(width: 600, height: 450)
        .padding()
        .background(.clear)
    }
}

#Preview("Look Away Setup View") {
    LookAwaySetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(20),
        countdownSeconds: .constant(20)
    )
}
