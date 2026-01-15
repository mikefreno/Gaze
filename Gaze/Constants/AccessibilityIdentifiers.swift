//
//  AccessibilityIdentifiers.swift
//  Gaze
//
//  Centralized accessibility identifiers for UI testing.
//

import Foundation

/// Centralized accessibility identifiers for UI elements.
/// Use these in SwiftUI views with `.accessibilityIdentifier()` modifier.
enum AccessibilityIdentifiers {
    
    // MARK: - Reminders
    
    enum Reminders {
        static let lookAwayView = "reminder.lookAway"
        static let blinkView = "reminder.blink"
        static let postureView = "reminder.posture"
        static let userTimerView = "reminder.userTimer"
        static let userTimerOverlayView = "reminder.userTimerOverlay"
        static let dismissButton = "reminder.dismissButton"
        static let countdownLabel = "reminder.countdown"
    }
    
    // MARK: - Menu Bar
    
    enum MenuBar {
        static let contentView = "menuBar.content"
        static let timerRow = "menuBar.timerRow"
        static let pauseButton = "menuBar.pauseButton"
        static let resumeButton = "menuBar.resumeButton"
        static let skipButton = "menuBar.skipButton"
        static let settingsButton = "menuBar.settingsButton"
        static let quitButton = "menuBar.quitButton"
    }
    
    // MARK: - Settings
    
    enum Settings {
        static let window = "settings.window"
        static let generalTab = "settings.tab.general"
        static let timersTab = "settings.tab.timers"
        static let smartModeTab = "settings.tab.smartMode"
        static let aboutTab = "settings.tab.about"
        
        // Timer settings
        static let lookAwayToggle = "settings.lookAway.toggle"
        static let lookAwayInterval = "settings.lookAway.interval"
        static let blinkToggle = "settings.blink.toggle"
        static let blinkInterval = "settings.blink.interval"
        static let postureToggle = "settings.posture.toggle"
        static let postureInterval = "settings.posture.interval"
        
        // General settings
        static let launchAtLoginToggle = "settings.launchAtLogin.toggle"
        static let playSoundsToggle = "settings.playSounds.toggle"
    }
    
    // MARK: - Onboarding
    
    enum Onboarding {
        static let window = "onboarding.window"
        static let welcomePage = "onboarding.page.welcome"
        static let lookAwayPage = "onboarding.page.lookAway"
        static let blinkPage = "onboarding.page.blink"
        static let posturePage = "onboarding.page.posture"
        static let generalPage = "onboarding.page.general"
        static let completionPage = "onboarding.page.completion"
        static let continueButton = "onboarding.button.continue"
        static let backButton = "onboarding.button.back"
    }
}
