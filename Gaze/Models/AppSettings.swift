//
//  AppSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

struct AppSettings: Codable, Equatable {
    var lookAwayTimer: TimerConfiguration
    var lookAwayCountdownSeconds: Int
    var blinkTimer: TimerConfiguration
    var postureTimer: TimerConfiguration
    var hasCompletedOnboarding: Bool
    var launchAtLogin: Bool
    var playSounds: Bool
    
    static var defaults: AppSettings {
        AppSettings(
            lookAwayTimer: TimerConfiguration(enabled: true, intervalSeconds: 20 * 60),
            lookAwayCountdownSeconds: 20,
            blinkTimer: TimerConfiguration(enabled: true, intervalSeconds: 5 * 60),
            postureTimer: TimerConfiguration(enabled: true, intervalSeconds: 30 * 60),
            hasCompletedOnboarding: false,
            launchAtLogin: false,
            playSounds: true
        )
    }
    
    static func == (lhs: AppSettings, rhs: AppSettings) -> Bool {
        lhs.lookAwayTimer == rhs.lookAwayTimer &&
        lhs.lookAwayCountdownSeconds == rhs.lookAwayCountdownSeconds &&
        lhs.blinkTimer == rhs.blinkTimer &&
        lhs.postureTimer == rhs.postureTimer &&
        lhs.hasCompletedOnboarding == rhs.hasCompletedOnboarding &&
        lhs.launchAtLogin == rhs.launchAtLogin &&
        lhs.playSounds == rhs.playSounds
    }
}
