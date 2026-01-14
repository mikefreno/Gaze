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
            if #available(macOS 15.0, *) {
                TabView(selection: $selectedSection) {
                    Tab(
                        SettingsSection.general.title,
                        systemImage: SettingsSection.general.iconName,
                        value: SettingsSection.general
                    ) {
                        GeneralSetupView(
                            settingsManager: settingsManager,
                            isOnboarding: false
                        )
                    }

                    Tab(
                        SettingsSection.lookAway.title,
                        systemImage: SettingsSection.lookAway.iconName,
                        value: SettingsSection.lookAway
                    ) {
                        LookAwaySetupView(settingsManager: settingsManager)
                    }

                    Tab(
                        SettingsSection.blink.title, systemImage: SettingsSection.blink.iconName,
                        value: SettingsSection.blink
                    ) {
                        BlinkSetupView(settingsManager: settingsManager)
                    }

                    Tab(
                        SettingsSection.posture.title,
                        systemImage: SettingsSection.posture.iconName,
                        value: SettingsSection.posture
                    ) {
                        PostureSetupView(settingsManager: settingsManager)
                    }

                    Tab(
                        SettingsSection.userTimers.title,
                        systemImage: SettingsSection.userTimers.iconName,
                        value: SettingsSection.userTimers
                    ) {
                        UserTimersView(
                            userTimers: Binding(
                                get: { settingsManager.settings.userTimers },
                                set: { settingsManager.settings.userTimers = $0 }
                            )
                        )
                    }
                    Tab(
                        SettingsSection.enforceMode.title,
                        systemImage: SettingsSection.enforceMode.iconName,
                        value: SettingsSection.enforceMode
                    ) {
                        EnforceModeSetupView(settingsManager: settingsManager)
                    }

                    Tab(
                        SettingsSection.smartMode.title,
                        systemImage: SettingsSection.smartMode.iconName,
                        value: SettingsSection.smartMode
                    ) {
                        SmartModeSetupView(settingsManager: settingsManager)
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
            } else {
                // Fallback for macOS 14 and earlier - use a consistent sidebar approach without collapse button
                NavigationSplitView {
                    List(SettingsSection.allCases, selection: $selectedSection) { section in
                        NavigationLink(value: section) {
                            Label(section.title, systemImage: section.iconName)
                        }
                    }
                    .navigationTitle("Settings")
                    .listStyle(.sidebar)
                } detail: {
                    detailView(for: selectedSection)
                }
                // Disable the ability to collapse the sidebar by explicitly setting a fixed width
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
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
            // Close settings window first
            closeWindow()

            // Get AppDelegate and open onboarding
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                // Reset onboarding state so it shows as fresh
                settingsManager.settings.hasCompletedOnboarding = false

                // Open onboarding window
                appDelegate.openOnboarding()
            }
        }
    #endif
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}