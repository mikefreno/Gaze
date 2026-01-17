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

    var body: some Scene {
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
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
