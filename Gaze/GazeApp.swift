//
//  GazeApp.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

@main
struct GazeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settingsManager = SettingsManager.shared

    init() {
        // Handle test launch arguments
        if TestingEnvironment.shouldSkipOnboarding {
            SettingsManager.shared.settings.hasCompletedOnboarding = true
        } else if TestingEnvironment.shouldResetOnboarding {
            SettingsManager.shared.settings.hasCompletedOnboarding = false
        }
    }

    var body: some Scene {
        // Onboarding window (only shown when not completed)
        WindowGroup {
            if settingsManager.settings.hasCompletedOnboarding {
                EmptyView()
                    .onAppear {
                        closeAllWindows()
                    }
            } else {
                OnboardingContainerView(settingsManager: settingsManager)
                    .onChange(of: settingsManager.settings.hasCompletedOnboarding) { _, completed in
                        if completed {
                            closeAllWindows()
                            appDelegate.onboardingCompleted()
                        }
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 700, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // Menu bar extra (always present)
        MenuBarExtra("Gaze", systemImage: "eye.fill") {
            MenuBarContentWrapper(
                appDelegate: appDelegate,
                settingsManager: settingsManager,
                onQuit: { NSApplication.shared.terminate(nil) },
                onOpenSettings: { appDelegate.openSettings() },
                onOpenSettingsTab: { tab in appDelegate.openSettings(tab: tab) },
                onOpenOnboarding: { appDelegate.openOnboarding() }
            )
        }
        .menuBarExtraStyle(.window)
    }

    private func closeAllWindows() {
        for window in NSApplication.shared.windows {
            window.close()
        }
    }
}
