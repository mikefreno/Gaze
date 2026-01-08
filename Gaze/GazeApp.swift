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
            } else {
                OnboardingContainerView(settingsManager: settingsManager)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
