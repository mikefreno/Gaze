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
    
    var body: some Scene {
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
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    private func closeAllWindows() {
        for window in NSApplication.shared.windows {
            window.close()
        }
    }
}
