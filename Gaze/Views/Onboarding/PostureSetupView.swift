//
//  PostureSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct PostureSetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Posture Reminder")
                .font(.system(size: 28, weight: .bold))

            Text("Maintain proper ergonomics")
                .font(.title3)
                .foregroundColor(.secondary)

            // InfoBox with link functionality
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(
                        string: "https://www.healthline.com/health/ergonomic-workspace")
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
                Text(
                    "Regular posture checks help prevent back and neck pain from prolonged sitting"
                )
                .font(.headline)
                .foregroundColor(.white)
            }
            .padding()
            .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: 8))

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
            .glassEffect(.regular, in: .rect(cornerRadius: 12))

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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
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
