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
    @State private var lookAwayEnabled: Bool
    @State private var lookAwayIntervalMinutes: Int
    @State private var lookAwayCountdownSeconds: Int
    @State private var blinkEnabled: Bool
    @State private var blinkIntervalMinutes: Int
    @State private var postureEnabled: Bool
    @State private var postureIntervalMinutes: Int
    @State private var launchAtLogin: Bool
    
    init(settingsManager: SettingsManager, initialTab: Int = 0) {
        self.settingsManager = settingsManager
        
        _currentTab = State(initialValue: initialTab)
        _lookAwayEnabled = State(initialValue: settingsManager.settings.lookAwayTimer.enabled)
        _lookAwayIntervalMinutes = State(initialValue: settingsManager.settings.lookAwayTimer.intervalSeconds / 60)
        _lookAwayCountdownSeconds = State(initialValue: settingsManager.settings.lookAwayCountdownSeconds)
        _blinkEnabled = State(initialValue: settingsManager.settings.blinkTimer.enabled)
        _blinkIntervalMinutes = State(initialValue: settingsManager.settings.blinkTimer.intervalSeconds / 60)
        _postureEnabled = State(initialValue: settingsManager.settings.postureTimer.enabled)
        _postureIntervalMinutes = State(initialValue: settingsManager.settings.postureTimer.intervalSeconds / 60)
        _launchAtLogin = State(initialValue: settingsManager.settings.launchAtLogin)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentTab) {
                LookAwaySetupView(
                    enabled: $lookAwayEnabled,
                    intervalMinutes: $lookAwayIntervalMinutes,
                    countdownSeconds: $lookAwayCountdownSeconds
                )
                .tag(0)
                .tabItem {
                    Label("Look Away", systemImage: "eye.fill")
                }
                
                BlinkSetupView(
                    enabled: $blinkEnabled,
                    intervalMinutes: $blinkIntervalMinutes
                )
                .tag(1)
                .tabItem {
                    Label("Blink", systemImage: "eye.circle.fill")
                }
                
                PostureSetupView(
                    enabled: $postureEnabled,
                    intervalMinutes: $postureIntervalMinutes
                )
                .tag(2)
                .tabItem {
                    Label("Posture", systemImage: "figure.stand")
                }
                
                SettingsOnboardingView(
                    launchAtLogin: $launchAtLogin,
                    isOnboarding: false
                )
                .tag(3)
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)
                
                Button("Apply") {
                    applySettings()
                    closeWindow()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 550)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToSettingsTab"))) { notification in
            if let tab = notification.object as? Int {
                currentTab = tab
            }
        }
    }
    
    private func applySettings() {
        settingsManager.settings.lookAwayTimer = TimerConfiguration(
            enabled: lookAwayEnabled,
            intervalSeconds: lookAwayIntervalMinutes * 60
        )
        settingsManager.settings.lookAwayCountdownSeconds = lookAwayCountdownSeconds
        
        settingsManager.settings.blinkTimer = TimerConfiguration(
            enabled: blinkEnabled,
            intervalSeconds: blinkIntervalMinutes * 60
        )
        
        settingsManager.settings.postureTimer = TimerConfiguration(
            enabled: postureEnabled,
            intervalSeconds: postureIntervalMinutes * 60
        )
        
        settingsManager.settings.launchAtLogin = launchAtLogin
        
        do {
            if launchAtLogin {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
    
    private func closeWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
            window.close()
        }
    }
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}
