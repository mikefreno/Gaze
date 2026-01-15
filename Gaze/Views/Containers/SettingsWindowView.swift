//
//  SettingsWindowView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var selectedSection: SettingsSection

    init(settingsManager: SettingsManager, initialTab: Int = 0) {
        self.settingsManager = settingsManager
        _selectedSection = State(initialValue: SettingsSection(rawValue: initialTab) ?? .general)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(SettingsSection.allCases, selection: $selectedSection) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.iconName)
                    }
                }
                .listStyle(.sidebar)
            } detail: {
                detailView(for: selectedSection)
            }

            Divider()

            HStack {
                #if DEBUG
                    Button("Retrigger Onboarding") {
                        retriggerOnboarding()
                    }
                    .buttonStyle(.bordered)
                #endif

                Spacer()

                Button("Close") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        #if APPSTORE
            .frame(
                minWidth: 1000,
                minHeight: 700
            )
        #else
            .frame(
                minWidth: 1000,
                minHeight: 900
            )
        #endif
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("SwitchToSettingsTab"))
        ) { notification in
            if let tab = notification.object as? Int,
                let section = SettingsSection(rawValue: tab)
            {
                selectedSection = section
            }
        }
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSetupView(
                settingsManager: settingsManager,
                isOnboarding: false
            )
        case .lookAway:
            LookAwaySetupView(settingsManager: settingsManager)
        case .blink:
            BlinkSetupView(settingsManager: settingsManager)
        case .posture:
            PostureSetupView(settingsManager: settingsManager)
        case .enforceMode:
            EnforceModeSetupView(settingsManager: settingsManager)
        case .userTimers:
            UserTimersView(
                userTimers: Binding(
                    get: { settingsManager.settings.userTimers },
                    set: { settingsManager.settings.userTimers = $0 }
                )
            )
        case .smartMode:
            SmartModeSetupView(settingsManager: settingsManager)
        }
    }

    private func closeWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            window.close()
        }
    }

    #if DEBUG
        private func retriggerOnboarding() {
            // Get AppDelegate reference first
            guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }

            // Step 1: Close any existing onboarding window
            if let onboardingWindow = NSApplication.shared.windows.first(where: {
                $0.identifier == WindowIdentifiers.onboarding
            }) {
                onboardingWindow.close()
            }

            // Step 2: Close settings window
            closeWindow()

            // Step 3: Reset onboarding state with a delay to ensure settings window is closed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.settingsManager.settings.hasCompletedOnboarding = false

                // Step 4: Open onboarding window with another delay to ensure state is saved
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    appDelegate.openOnboarding()
                }
            }
        }
    #endif
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}
