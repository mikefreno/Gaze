//
//  SettingsWindowView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var currentTab: Int

    init(settingsManager: SettingsManager, initialTab: Int = 0) {
        self.settingsManager = settingsManager
        _currentTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentTab) {
                LookAwaySetupView(settingsManager: settingsManager)
                    .tag(0)
                    .tabItem {
                        Label("Look Away", systemImage: "eye.fill")
                    }

                BlinkSetupView(settingsManager: settingsManager)
                    .tag(1)
                    .tabItem {
                        Label("Blink", systemImage: "eye.circle.fill")
                    }

                PostureSetupView(settingsManager: settingsManager)
                    .tag(2)
                    .tabItem {
                        Label("Posture", systemImage: "figure.stand")
                    }

                EnforceModeSetupView(settingsManager: settingsManager)
                    .tag(3)
                    .tabItem {
                        Label("Enforce Mode", systemImage: "video.fill")
                    }

                UserTimersView(
                    userTimers: Binding(
                        get: { settingsManager.settings.userTimers },
                        set: { settingsManager.settings.userTimers = $0 }
                    )
                )
                .tag(4)
                .tabItem {
                    Label("User Timers", systemImage: "plus.circle")
                }

                GeneralSetupView(
                    settingsManager: settingsManager,
                    isOnboarding: false
                )
                .tag(5)
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
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
                minWidth: 750,
                minHeight: 700
            )
        #else
            .frame(
                minWidth: 750,
                minHeight: 900
            )
        #endif
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("SwitchToSettingsTab"))
        ) { notification in
            if let tab = notification.object as? Int {
                currentTab = tab
            }
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
