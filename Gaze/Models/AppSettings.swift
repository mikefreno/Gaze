//
//  AppSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

// MARK: - Centralized Configuration System

/// Unified configuration class that manages all app settings in a centralized way
struct AppSettings: Codable, Equatable, Hashable {
    // Timer configurations
    var lookAwayTimer: TimerConfiguration
    var lookAwayCountdownSeconds: Int
    var blinkTimer: TimerConfiguration
    var postureTimer: TimerConfiguration

    // User-defined timers (up to 3)
    var userTimers: [UserTimer]

    // UI and display settings
    var subtleReminderSizePercentage: Double  // 0.5-25% of screen width

    // App state and behavior
    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var playSounds: Bool

    init(
        lookAwayTimer: TimerConfiguration = TimerConfiguration(
            enabled: true, intervalSeconds: 20 * 60),
        lookAwayCountdownSeconds: Int = 20,
        blinkTimer: TimerConfiguration = TimerConfiguration(
            enabled: false, intervalSeconds: 7 * 60),
        postureTimer: TimerConfiguration = TimerConfiguration(
            enabled: true, intervalSeconds: 30 * 60),
        userTimers: [UserTimer] = [],
        subtleReminderSizePercentage: Double = 5.0,
        hasCompletedOnboarding: Bool = false,
        launchAtLogin: Bool = false,
        playSounds: Bool = true
    ) {
        self.lookAwayTimer = lookAwayTimer
        self.lookAwayCountdownSeconds = lookAwayCountdownSeconds
        self.blinkTimer = blinkTimer
        self.postureTimer = postureTimer
        self.userTimers = userTimers
        // Clamp the subtle reminder size to valid range (2-35%)
        self.subtleReminderSizePercentage = max(2.0, min(35.0, subtleReminderSizePercentage))
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLogin = launchAtLogin
        self.playSounds = playSounds
    }

    static var defaults: AppSettings {
        AppSettings(
            lookAwayTimer: TimerConfiguration(enabled: true, intervalSeconds: 20 * 60),
            lookAwayCountdownSeconds: 20,
            blinkTimer: TimerConfiguration(enabled: false, intervalSeconds: 7 * 60),
            postureTimer: TimerConfiguration(enabled: true, intervalSeconds: 30 * 60),
            userTimers: [],
            subtleReminderSizePercentage: 5.0,
            hasCompletedOnboarding: false,
            launchAtLogin: false,
            playSounds: true
        )
    }

    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.lookAwayTimer == rhs.lookAwayTimer
            && lhs.lookAwayCountdownSeconds == rhs.lookAwayCountdownSeconds
            && lhs.blinkTimer == rhs.blinkTimer && lhs.postureTimer == rhs.postureTimer
            && lhs.userTimers == rhs.userTimers
            && lhs.subtleReminderSizePercentage == rhs.subtleReminderSizePercentage
            && lhs.hasCompletedOnboarding == rhs.hasCompletedOnboarding
            && lhs.launchAtLogin == rhs.launchAtLogin && lhs.playSounds == rhs.playSounds
    }
}
