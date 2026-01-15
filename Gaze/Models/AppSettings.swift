//
//  AppSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

// MARK: - Reminder Size

enum ReminderSize: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    var percentage: Double {
        switch self {
        case .small: return 1.5
        case .medium: return 2.5
        case .large: return 5.0
        }
    }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

struct AppSettings: Codable, Equatable, Hashable, Sendable {
    var lookAwayTimer: TimerConfiguration
    var lookAwayCountdownSeconds: Int
    var blinkTimer: TimerConfiguration
    var postureTimer: TimerConfiguration
    var enforcementMode: Bool = false

    var userTimers: [UserTimer]

    var subtleReminderSize: ReminderSize
    
    var smartMode: SmartModeSettings

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
        subtleReminderSize: ReminderSize = .medium,
        smartMode: SmartModeSettings = .defaults,
        hasCompletedOnboarding: Bool = false,
        launchAtLogin: Bool = false,
        playSounds: Bool = true
    ) {
        self.lookAwayTimer = lookAwayTimer
        self.lookAwayCountdownSeconds = lookAwayCountdownSeconds
        self.blinkTimer = blinkTimer
        self.postureTimer = postureTimer
        self.userTimers = userTimers
        self.subtleReminderSize = subtleReminderSize
        self.smartMode = smartMode
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
            subtleReminderSize: .medium,
            smartMode: .defaults,
            hasCompletedOnboarding: false,
            launchAtLogin: false,
            playSounds: true
        )
    }
}
