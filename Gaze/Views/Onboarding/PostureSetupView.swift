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
    
    @State private var isPreviewShowing = false

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
                        if let url = URL(
                            string:
                                "https://pubmed.ncbi.nlm.nih.gov/40111906/#:~:text=For studies exploring sitting posture, seven found a relationship with LBP. Regarding studies on sitting behavior, only one showed no relationship between LBP prevalence, while twelve indicated a relationship."
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
                
                // Preview button
                Button(action: {
                    isPreviewShowing = true
                }) {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(.white)
                        Text("Preview Reminder")
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue)
                    .cornerRadius(8)
                }
                .fullScreenCover(isPresented: $isPreviewShowing) {
                    PostureReminderView(sizePercentage: 10.0, onDismiss: {
                        isPreviewShowing = false
                    })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black.opacity(0.85))
                }
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
