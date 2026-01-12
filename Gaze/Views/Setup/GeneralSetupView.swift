//
//  GeneralSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct GeneralSetupView: View {
    @Binding var launchAtLogin: Bool
    @Binding var subtleReminderSize: ReminderSize
    @Binding var isAppStoreVersion: Bool
    @ObservedObject var updateManager = UpdateManager.shared
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

            Spacer()
            VStack(spacing: 30) {
                Text("Configure app preferences and support the project")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 20) {
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
                            .onChange(of: launchAtLogin) { isEnabled in
                                applyLaunchAtLoginSetting(enabled: isEnabled)
                            }
                    }
                    .padding()
                    .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                    // Software Updates Section
                    if !isAppStoreVersion {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Software Updates")
                                    .font(.headline)

                                if let lastCheck = updateManager.lastUpdateCheckDate {
                                    Text("Last checked: \(lastCheck, style: .relative)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                } else {
                                    Text("Never checked for updates")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }

                            Spacer()

                            Button("Check for Updates Now") {
                                updateManager.checkForUpdates()
                            }
                            .buttonStyle(.bordered)

                            Toggle(
                                "Automatically check for updates",
                                isOn: $updateManager.automaticallyChecksForUpdates
                            )
                            .labelsHidden()
                            .help("Check for new versions of Gaze in the background")
                        }
                        .padding()
                        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subtle Reminder Size")
                            .font(.headline)

                        Text("Adjust the size of blink and posture reminders")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(ReminderSize.allCases, id: \.self) { size in
                                Button(action: {
                                    subtleReminderSize = size
                                }) {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(
                                                subtleReminderSize == size
                                                    ? Color.accentColor
                                                    : Color.secondary.opacity(0.3)
                                            )
                                            .frame(
                                                width: iconSize(for: size),
                                                height: iconSize(for: size))

                                        Text(size.displayName)
                                            .font(.caption)
                                            .fontWeight(
                                                subtleReminderSize == size ? .semibold : .regular
                                            )
                                            .foregroundColor(
                                                subtleReminderSize == size ? .primary : .secondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                    .padding(.vertical, 12)
                                }
                                .glassEffectIfAvailable(
                                    subtleReminderSize == size
                                        ? GlassStyle.regular.tint(.accentColor.opacity(0.3))
                                        : GlassStyle.regular,
                                    in: .rect(cornerRadius: 10)
                                )
                            }
                        }
                    }
                    .padding()
                    .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

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
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .glassEffectIfAvailable(
                            GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10))

                        if !isAppStoreVersion {
                            Button(action: {
                                if let url = URL(string: "https://buymeacoffee.com/mikefreno") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.title3)
                                        .foregroundColor(.brown)
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
                                .cornerRadius(10)
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .glassEffectIfAvailable(
                                GlassStyle.regular.tint(.orange).interactive(),
                                in: .rect(cornerRadius: 10))
                        }
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

    private func iconSize(for size: ReminderSize) -> CGFloat {
        switch size {
        case .small: return 20
        case .medium: return 32
        case .large: return 48
        }
    }
}

#Preview("Settings Onboarding") {
    GeneralSetupView(
        launchAtLogin: .constant(false),
        subtleReminderSize: .constant(.medium),
        isAppStoreVersion: .constant(false),
        isOnboarding: true
    )
}
