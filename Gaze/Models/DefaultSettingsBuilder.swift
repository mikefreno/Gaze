//
//  DefaultSettingsBuilder.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Foundation

struct DefaultSettingsBuilder {
    static let lookAwayEnabled = true
    static let lookAwayIntervalMinutes = 20
    static let blinkEnabled = false
    static let blinkIntervalMinutes = 7
    static let postureEnabled = true
    static let postureIntervalMinutes = 30
    static let subtleReminderSize: ReminderSize = .medium
    static let smartMode: SmartModeSettings = .defaults
    static let enforceModeStrictness = 0.4
    static let enforceModeEyeBoxWidthFactor = 0.18
    static let enforceModeEyeBoxHeightFactor = 0.10
    static let enforceModeCalibration: EnforceModeCalibration? = nil
    static let hasCompletedOnboarding = false
    static let launchAtLogin = false
    static let playSounds = true

    static func makeDefaults() -> AppSettings {
        AppSettings(
            lookAwayEnabled: lookAwayEnabled,
            lookAwayIntervalMinutes: lookAwayIntervalMinutes,
            blinkEnabled: blinkEnabled,
            blinkIntervalMinutes: blinkIntervalMinutes,
            postureEnabled: postureEnabled,
            postureIntervalMinutes: postureIntervalMinutes,
            userTimers: [],
            subtleReminderSize: subtleReminderSize,
            smartMode: smartMode,
            enforceModeStrictness: enforceModeStrictness,
            enforceModeEyeBoxWidthFactor: enforceModeEyeBoxWidthFactor,
            enforceModeEyeBoxHeightFactor: enforceModeEyeBoxHeightFactor,
            enforceModeCalibration: enforceModeCalibration,
            hasCompletedOnboarding: hasCompletedOnboarding,
            launchAtLogin: launchAtLogin,
            playSounds: playSounds
        )
    }
}
