//
//  ReminderTriggerService.swift
//  Gaze
//
//  Creates reminder events and coordinates enforce mode behavior.
//

import Foundation

@MainActor
final class ReminderTriggerService {
    private let settingsProvider: any SettingsProviding
    private let enforceModeService: EnforceModeService?

    init(
        settingsProvider: any SettingsProviding,
        enforceModeService: EnforceModeService?
    ) {
        self.settingsProvider = settingsProvider
        self.enforceModeService = enforceModeService
    }

    func reminderEvent(for identifier: TimerIdentifier) -> ReminderEvent? {
        switch identifier {
        case .builtIn(let type):
            switch type {
            case .lookAway:
                return .lookAwayTriggered(
                    countdownSeconds: settingsProvider.settings.lookAwayIntervalMinutes * 60
                )
            case .blink:
                return .blinkTriggered
            case .posture:
                return .postureTriggered
            }
        case .user(let id):
            guard let userTimer = settingsProvider.settings.userTimers.first(where: { $0.id == id }) else {
                return nil
            }
            return .userTimerTriggered(userTimer)
        }
    }

    func shouldPrepareEnforceMode(for identifier: TimerIdentifier, secondsRemaining: Int) -> Bool {
        guard secondsRemaining <= 3 else { return false }
        return enforceModeService?.shouldEnforceBreak(for: identifier) ?? false
    }

    func prepareEnforceMode(secondsRemaining: Int) async {
        await enforceModeService?.startCameraForLookawayTimer(secondsRemaining: secondsRemaining)
    }

    func handleReminderDismissed() {
        enforceModeService?.handleReminderDismissed()
    }
}
