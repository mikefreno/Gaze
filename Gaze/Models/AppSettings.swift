//
//  AppSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

// MARK: - Reminder Size

enum ReminderSize: String, Codable, CaseIterable {
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

// MARK: - Centralized Configuration System

/// Unified configuration class that manages all app settings in a centralized way
struct AppSettings: Codable, Equatable, Hashable {
    // Timer configurations
    var lookAwayTimer: TimerConfiguration
    var lookAwayCountdownSeconds: Int
    var blinkTimer: TimerConfiguration
    var postureTimer: TimerConfiguration

    var userTimers: [UserTimer]

    var subtleReminderSize: ReminderSize

    // App state and behavior
    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var playSounds: Bool

    // App Store detection (cached at launch, not persisted)
    var isAppStoreVersion: Bool

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
        hasCompletedOnboarding: Bool = false,
        launchAtLogin: Bool = false,
        playSounds: Bool = true,
        isAppStoreVersion: Bool = true
    ) {
        self.lookAwayTimer = lookAwayTimer
        self.lookAwayCountdownSeconds = lookAwayCountdownSeconds
        self.blinkTimer = blinkTimer
        self.postureTimer = postureTimer
        self.userTimers = userTimers
        self.subtleReminderSize = subtleReminderSize
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLogin = launchAtLogin
        self.playSounds = playSounds
        self.isAppStoreVersion = isAppStoreVersion
    }

    static var defaults: AppSettings {
        AppSettings(
            lookAwayTimer: TimerConfiguration(enabled: true, intervalSeconds: 20 * 60),
            lookAwayCountdownSeconds: 20,
            blinkTimer: TimerConfiguration(enabled: false, intervalSeconds: 7 * 60),
            postureTimer: TimerConfiguration(enabled: true, intervalSeconds: 30 * 60),
            userTimers: [],
            subtleReminderSize: .medium,
            hasCompletedOnboarding: false,
            launchAtLogin: false,
            playSounds: true,
            isAppStoreVersion: false
        )
    }

    /// Manual Equatable implementation required because isAppStoreVersion
    /// is excluded from Codable persistence but included in equality checks
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.lookAwayTimer == rhs.lookAwayTimer
            && lhs.lookAwayCountdownSeconds == rhs.lookAwayCountdownSeconds
            && lhs.blinkTimer == rhs.blinkTimer
            && lhs.postureTimer == rhs.postureTimer
            && lhs.userTimers == rhs.userTimers
            && lhs.subtleReminderSize == rhs.subtleReminderSize
            && lhs.hasCompletedOnboarding == rhs.hasCompletedOnboarding
            && lhs.launchAtLogin == rhs.launchAtLogin
            && lhs.playSounds == rhs.playSounds
            && lhs.isAppStoreVersion == rhs.isAppStoreVersion
    }

    // MARK: - Custom Codable Implementation

    enum CodingKeys: String, CodingKey {
        case lookAwayTimer
        case lookAwayCountdownSeconds
        case blinkTimer
        case postureTimer
        case userTimers
        case subtleReminderSize
        case hasCompletedOnboarding
        case launchAtLogin
        case playSounds
        // isAppStoreVersion is intentionally excluded from persistence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lookAwayTimer = try container.decode(TimerConfiguration.self, forKey: .lookAwayTimer)
        lookAwayCountdownSeconds = try container.decode(Int.self, forKey: .lookAwayCountdownSeconds)
        blinkTimer = try container.decode(TimerConfiguration.self, forKey: .blinkTimer)
        postureTimer = try container.decode(TimerConfiguration.self, forKey: .postureTimer)
        userTimers = try container.decode([UserTimer].self, forKey: .userTimers)
        subtleReminderSize = try container.decode(ReminderSize.self, forKey: .subtleReminderSize)
        hasCompletedOnboarding = try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        playSounds = try container.decode(Bool.self, forKey: .playSounds)
        // isAppStoreVersion is not persisted, will be set at launch
        isAppStoreVersion = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lookAwayTimer, forKey: .lookAwayTimer)
        try container.encode(lookAwayCountdownSeconds, forKey: .lookAwayCountdownSeconds)
        try container.encode(blinkTimer, forKey: .blinkTimer)
        try container.encode(postureTimer, forKey: .postureTimer)
        try container.encode(userTimers, forKey: .userTimers)
        try container.encode(subtleReminderSize, forKey: .subtleReminderSize)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(playSounds, forKey: .playSounds)
        // isAppStoreVersion is intentionally not persisted
    }
}
