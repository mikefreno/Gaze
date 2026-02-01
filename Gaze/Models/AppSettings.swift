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
    var lookAwayCountdownSeconds: Int
    var blinkEnabled: Bool
    var blinkIntervalMinutes: Int
    var postureEnabled: Bool
    var postureIntervalMinutes: Int

    var userTimers: [UserTimer]

    var subtleReminderSize: ReminderSize

    var smartMode: SmartModeSettings
    var enforceModeEyeBoxWidthFactor: Double
    var enforceModeEyeBoxHeightFactor: Double
    var enforceModeCalibration: EnforceModeCalibration?

    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var playSounds: Bool

    init(
        lookAwayEnabled: Bool = DefaultSettingsBuilder.lookAwayEnabled,
        lookAwayIntervalMinutes: Int = DefaultSettingsBuilder.lookAwayIntervalMinutes,
        lookAwayCountdownSeconds: Int = DefaultSettingsBuilder.lookAwayCountdownSeconds,
        blinkEnabled: Bool = DefaultSettingsBuilder.blinkEnabled,
        blinkIntervalMinutes: Int = DefaultSettingsBuilder.blinkIntervalMinutes,
        postureEnabled: Bool = DefaultSettingsBuilder.postureEnabled,
        postureIntervalMinutes: Int = DefaultSettingsBuilder.postureIntervalMinutes,
        userTimers: [UserTimer] = [],
        subtleReminderSize: ReminderSize = DefaultSettingsBuilder.subtleReminderSize,
        smartMode: SmartModeSettings = DefaultSettingsBuilder.smartMode,
        enforceModeEyeBoxWidthFactor: Double = DefaultSettingsBuilder.enforceModeEyeBoxWidthFactor,
        enforceModeEyeBoxHeightFactor: Double = DefaultSettingsBuilder.enforceModeEyeBoxHeightFactor,
        enforceModeCalibration: EnforceModeCalibration? = DefaultSettingsBuilder.enforceModeCalibration,
        hasCompletedOnboarding: Bool = DefaultSettingsBuilder.hasCompletedOnboarding,
        launchAtLogin: Bool = DefaultSettingsBuilder.launchAtLogin,
        playSounds: Bool = DefaultSettingsBuilder.playSounds
    ) {
        self.lookAwayEnabled = lookAwayEnabled
        self.lookAwayIntervalMinutes = lookAwayIntervalMinutes
        self.lookAwayCountdownSeconds = lookAwayCountdownSeconds
        self.blinkEnabled = blinkEnabled
        self.blinkIntervalMinutes = blinkIntervalMinutes
        self.postureEnabled = postureEnabled
        self.postureIntervalMinutes = postureIntervalMinutes
        self.userTimers = userTimers
        self.subtleReminderSize = subtleReminderSize
        self.smartMode = smartMode
        self.enforceModeEyeBoxWidthFactor = enforceModeEyeBoxWidthFactor
        self.enforceModeEyeBoxHeightFactor = enforceModeEyeBoxHeightFactor
        self.enforceModeCalibration = enforceModeCalibration
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.launchAtLogin = launchAtLogin
        self.playSounds = playSounds
    }

    static var defaults: AppSettings {
        DefaultSettingsBuilder.makeDefaults()
    }
}
