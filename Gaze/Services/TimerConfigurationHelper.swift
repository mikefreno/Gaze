//
//  TimerConfigurationHelper.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Foundation

struct TimerConfigurationHelper {
    let settingsProvider: any SettingsProviding

    func intervalSeconds(for identifier: TimerIdentifier) -> Int {
        switch identifier {
        case .builtIn(let type):
            return settingsProvider.timerIntervalMinutes(for: type) * 60
        case .user(let id):
            guard let userTimer = settingsProvider.settings.userTimers.first(where: { $0.id == id }) else {
                return 0
            }
            return userTimer.intervalMinutes * 60
        }
    }

    func configuration(for identifier: TimerIdentifier) -> (enabled: Bool, intervalSeconds: Int)? {
        switch identifier {
        case .builtIn(let type):
            let intervalSeconds = settingsProvider.timerIntervalMinutes(for: type) * 60
            return (enabled: settingsProvider.isTimerEnabled(for: type), intervalSeconds: intervalSeconds)
        case .user(let id):
            guard let userTimer = settingsProvider.settings.userTimers.first(where: { $0.id == id }), userTimer.enabled else {
                return nil
            }
            return (enabled: true, intervalSeconds: userTimer.intervalMinutes * 60)
        }
    }
}
