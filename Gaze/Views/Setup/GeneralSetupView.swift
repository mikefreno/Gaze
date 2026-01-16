//
//  GeneralSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct GeneralSetupView: View {
    @Bindable var settingsManager: SettingsManager
    var updateManager = UpdateManager.shared
    var isOnboarding: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(
                icon: "gearshape.fill", title: isOnboarding ? "Final Settings" : "General Settings",
                color: .accentColor)

            Spacer()
            VStack(spacing: 30) {
                Text("Configure app preferences and support the project")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 20) {
                    launchAtLoginToggle

                    #if !APPSTORE
                        softwareUpdatesSection
                    #endif

                    subtleReminderSizeSection

                    #if !APPSTORE
                        supportSection
                    #endif
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private var launchAtLoginToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Launch at Login")
                    .font(.headline)
                Text("Start Gaze automatically when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $settingsManager.settings.launchAtLogin)
                .labelsHidden()
                .onChange(of: settingsManager.settings.launchAtLogin) { _, isEnabled in
                    applyLaunchAtLoginSetting(enabled: isEnabled)
                }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    #if !APPSTORE
        private var softwareUpdatesSection: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Software Updates")
                        .font(.headline)

                    if let lastCheck = updateManager.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text("Never checked for updates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    isOn: Binding(
                        get: { updateManager.automaticallyChecksForUpdates },
                        set: { updateManager.automaticallyChecksForUpdates = $0 }
                    )
                )
                .labelsHidden()
                .help("Check for new versions of Gaze in the background")
            }
            .padding()
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
        }
    #endif

    private var subtleReminderSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subtle Reminder Size")
                .font(.headline)

            Text("Adjust the size of blink and posture reminders")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(ReminderSize.allCases, id: \.self) { size in
                    Button(action: { settingsManager.settings.subtleReminderSize = size }) {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(
                                    settingsManager.settings.subtleReminderSize == size
                                        ? Color.accentColor : Color.secondary.opacity(0.3)
                                )
                                .frame(width: iconSize(for: size), height: iconSize(for: size))

                            Text(size.displayName)
                                .font(.caption)
                                .fontWeight(
                                    settingsManager.settings.subtleReminderSize == size
                                        ? .semibold : .regular
                                )
                                .foregroundStyle(
                                    settingsManager.settings.subtleReminderSize == size
                                        ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.vertical, 12)
                    }
                    .glassEffectIfAvailable(
                        settingsManager.settings.subtleReminderSize == size
                            ? GlassStyle.regular.tint(.accentColor.opacity(0.3))
                            : GlassStyle.regular,
                        in: .rect(cornerRadius: 10)
                    )
                }
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    #if !APPSTORE
        private var supportSection: some View {
            VStack(spacing: 12) {
                Text("Support & Contribute")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ExternalLinkButton(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "View on GitHub",
                    subtitle: "Star the repo, report issues, contribute",
                    url: "https://github.com/mikefreno/Gaze",
                    tint: nil
                )

                ExternalLinkButton(
                    icon: "cup.and.saucer.fill",
                    iconColor: .brown,
                    title: "Buy Me a Coffee",
                    subtitle: "Support development of Gaze",
                    url: "https://buymeacoffee.com/mikefreno",
                    tint: .orange
                )
            }
            .padding()
        }
    #endif

    private func applyLaunchAtLoginSetting(enabled: Bool) {
        do {
            if enabled {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {}
    }

    private func iconSize(for size: ReminderSize) -> CGFloat {
        switch size {
        case .small: return 20
        case .medium: return 32
        case .large: return 48
        }
    }
}

struct ExternalLinkButton: View {
    let icon: String
    var iconColor: Color = .primary
    let title: String
    let subtitle: String
    let url: String
    let tint: Color?

    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            tint != nil
                ? GlassStyle.regular.tint(tint!).interactive() : GlassStyle.regular.interactive(),
            in: .rect(cornerRadius: 10)
        )
    }
}

#Preview("Settings Onboarding") {
    GeneralSetupView(settingsManager: SettingsManager.shared, isOnboarding: true)
}
