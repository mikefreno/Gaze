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

    func configurations() -> [TimerIdentifier: TimerConfiguration] {
        var configurations: [TimerIdentifier: TimerConfiguration] = [:]
        for timerType in TimerType.allCases {
            let intervalSeconds = settingsProvider.timerIntervalMinutes(for: timerType) * 60
            configurations[.builtIn(timerType)] = TimerConfiguration(
                enabled: settingsProvider.isTimerEnabled(for: timerType),
                intervalSeconds: intervalSeconds
            )
        }
        return configurations
    }
}
