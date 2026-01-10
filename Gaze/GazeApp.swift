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
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var menuBarRefreshID = 0
    
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
                    .onChange(of: settingsManager.settings.hasCompletedOnboarding) { completed in
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
            CommandGroup(replacing: .newItem) { }
        }
        
        // Menu bar extra (always present once onboarding is complete)
        MenuBarExtra("Gaze", systemImage: "eye.fill") {
            if let timerEngine = appDelegate.timerEngine {
                MenuBarContentView(
                    timerEngine: timerEngine,
                    settingsManager: settingsManager,
                    onQuit: { NSApplication.shared.terminate(nil) },
                    onOpenSettings: { appDelegate.openSettings() },
                    onOpenSettingsTab: { tab in appDelegate.openSettings(tab: tab) }
                )
                .id(menuBarRefreshID)
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: settingsManager.settings) { _ in
            menuBarRefreshID += 1
        }
    }
    
    private func closeAllWindows() {
        for window in NSApplication.shared.windows {
            window.close()
        }
    }
}