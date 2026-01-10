//
//  SettingsOnboardingView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct SettingsOnboardingView: View {
    @Binding var launchAtLogin: Bool
    @Binding var subtleReminderSizePercentage: Double
    var isOnboarding: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            VStack(spacing: 16) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                Text(isOnboarding ? "Final Settings" : "General Settings")
                    .font(.system(size: 28, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

            // Vertically centered content
            Spacer()
            VStack(spacing: 30) {
                Text("Configure app preferences and support the project")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 20) {
                    // Launch at Login Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at Login")
                                .font(.headline)
                            Text("Start Gaze automatically when you log in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .onChange(of: launchAtLogin) { oldValue, newValue in
                                applyLaunchAtLoginSetting(enabled: newValue)
                            }
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                    // Subtle Reminder Size Configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subtle Reminder Size")
                            .font(.headline)
                        
                        Text("Adjust the size of blink and posture reminders")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(
                                value: $subtleReminderSizePercentage,
                                in: 2...35,
                                step: 1
                            )
                            Text("\(Int(subtleReminderSizePercentage))%")
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                    // Links Section
                    VStack(spacing: 12) {
                        Text("Support & Contribute")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // GitHub Link
                        Button(action: {
                            if let url = URL(string: "https://github.com/mikefreno/Gaze") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View on GitHub")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Star the repo, report issues, contribute")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))

                        // Buy Me a Coffee
                        Button(action: {
                            if let url = URL(string: "https://buymeacoffee.com/placeholder") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Buy Me a Coffee")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Support development of Gaze")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(.orange).interactive(), in: .rect(cornerRadius: 10))
                    }
                    .padding()
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private func applyLaunchAtLoginSetting(enabled: Bool) {
        do {
            if enabled {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

#Preview("Settings Onboarding - Launch Disabled") {
    SettingsOnboardingView(
        launchAtLogin: .constant(false),
        subtleReminderSizePercentage: .constant(5.0),
        isOnboarding: true
    )
}

#Preview("Settings Onboarding - Launch Enabled") {
    SettingsOnboardingView(
        launchAtLogin: .constant(true),
        subtleReminderSizePercentage: .constant(10.0),
        isOnboarding: true
    )
}
