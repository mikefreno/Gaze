//
//  ReminderManager.swift
//  Gaze
//
//  Manages reminder triggering and dismissal logic for timers.
//

import Combine
import Foundation

@MainActor
class ReminderManager: ObservableObject {
    @Published var activeReminder: ReminderEvent?
    
    private let settingsProvider: any SettingsProviding
    private var enforceModeService: EnforceModeService?
    private var timerEngine: TimerEngine?
    
    init(
        settingsProvider: any SettingsProviding,
        enforceModeService: EnforceModeService? = nil
    ) {
        self.settingsProvider = settingsProvider
        self.enforceModeService = enforceModeService ?? EnforceModeService.shared
    }
    
    func setTimerEngine(_ engine: TimerEngine) {
        self.timerEngine = engine
    }
    
    func triggerReminder(for identifier: TimerIdentifier) {
        // Pause only the timer that triggered
        timerEngine?.pauseTimer(identifier: identifier)
        
        // Unified approach to handle all timer types - no more special handling
        switch identifier {
        case .builtIn(let type):
            switch type {
            case .lookAway:
                activeReminder = .lookAwayTriggered(
                    countdownSeconds: settingsProvider.timerIntervalMinutes(for: .lookAway) * 60)
            case .blink:
                activeReminder = .blinkTriggered
            case .posture:
                activeReminder = .postureTriggered
            }
        case .user(let id):
            if let userTimer = settingsProvider.settings.userTimers.first(where: { $0.id == id }) {
                activeReminder = .userTimerTriggered(userTimer)
            }
        }
    }
    
    func dismissReminder() {
        guard let reminder = activeReminder else { return }
        activeReminder = nil
        
        let identifier = reminder.identifier
        timerEngine?.skipNext(identifier: identifier)
        timerEngine?.resumeTimer(identifier: identifier)
        
        enforceModeService?.handleReminderDismissed()
    }
}