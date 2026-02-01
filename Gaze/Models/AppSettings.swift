//
//  AppSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

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
    var lookAwayEnabled: Bool
    var lookAwayIntervalMinutes: Int
    var blinkEnabled: Bool
    var blinkIntervalMinutes: Int
    var postureEnabled: Bool
    var postureIntervalMinutes: Int

    var userTimers: [UserTimer]

    var subtleReminderSize: ReminderSize

    var smartMode: SmartModeSettings
    var enforceModeStrictness: Double

    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var playSounds: Bool

    init(
        lookAwayEnabled: Bool = DefaultSettingsBuilder.lookAwayEnabled,
        lookAwayIntervalMinutes: Int = DefaultSettingsBuilder.lookAwayIntervalMinutes,
        blinkEnabled: Bool = DefaultSettingsBuilder.blinkEnabled,
        blinkIntervalMinutes: Int = DefaultSettingsBuilder.blinkIntervalMinutes,
        postureEnabled: Bool = DefaultSettingsBuilder.postureEnabled,
        postureIntervalMinutes: Int = DefaultSettingsBuilder.postureIntervalMinutes,
        userTimers: [UserTimer] = [],
        subtleReminderSize: ReminderSize = DefaultSettingsBuilder.subtleReminderSize,
        smartMode: SmartModeSettings = DefaultSettingsBuilder.smartMode,
        enforceModeStrictness: Double = DefaultSettingsBuilder.enforceModeStrictness,
        hasCompletedOnboarding: Bool = DefaultSettingsBuilder.hasCompletedOnboarding,
        launchAtLogin: Bool = DefaultSettingsBuilder.launchAtLogin,
        playSounds: Bool = DefaultSettingsBuilder.playSounds
    ) {
        self.lookAwayEnabled = lookAwayEnabled
        self.lookAwayIntervalMinutes = lookAwayIntervalMinutes
        self.blinkEnabled = blinkEnabled
        self.blinkIntervalMinutes = blinkIntervalMinutes
        self.postureEnabled = postureEnabled
        self.postureIntervalMinutes = postureIntervalMinutes
        self.userTimers = userTimers
        self.subtleReminderSize = subtleReminderSize
        self.smartMode = smartMode
        self.enforceModeStrictness = enforceModeStrictness
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLogin = launchAtLogin
        self.playSounds = playSounds
    }

    static var defaults: AppSettings {
        DefaultSettingsBuilder.makeDefaults()
    }
}
