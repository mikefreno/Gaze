//
//  TimerEngine.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Combine
import Foundation

@MainActor
class TimerEngine: ObservableObject {
    @Published var timerStates: [TimerType: TimerState] = [:]
    @Published var activeReminder: ReminderEvent?

    private var timerSubscription: AnyCancellable?
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func start() {
        stop()

        for timerType in TimerType.allCases {
            let config = settingsManager.timerConfiguration(for: timerType)
            if config.enabled {
                timerStates[timerType] = TimerState(
                    type: timerType,
                    intervalSeconds: config.intervalSeconds,
                    isPaused: false,
                    isActive: true
                )
            }
        }

        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleTick()
                }
            }
    }

    func stop() {
        timerSubscription?.cancel()
        timerSubscription = nil
        timerStates.removeAll()
    }

    func pause() {
        for (type, _) in timerStates {
            timerStates[type]?.isPaused = true
        }
    }

    func resume() {
        for (type, _) in timerStates {
            timerStates[type]?.isPaused = false
        }
    }

    func skipNext(type: TimerType) {
        guard let state = timerStates[type] else { return }
        let config = settingsManager.timerConfiguration(for: type)
        timerStates[type] = TimerState(
            type: type,
            intervalSeconds: config.intervalSeconds,
            isPaused: state.isPaused,
            isActive: state.isActive
        )
    }

    func dismissReminder() {
        guard let reminder = activeReminder else { return }
        activeReminder = nil

        skipNext(type: reminder.type)

        if case .lookAwayTriggered = reminder {
            resume()
        }
    }

    private func handleTick() {
        guard activeReminder == nil else { return }

        for (type, state) in timerStates {
            guard state.isActive && !state.isPaused else { continue }
            // prevent overshoot - in case user closes laptop while timer is running, we don't want to
            // trigger on open,
            if state.targetDate < Date() - 3.0 {  // slight grace
                // Reset the timer when it has overshot its interval
                let config = settingsManager.timerConfiguration(for: type)
                timerStates[type] = TimerState(
                    type: type,
                    intervalSeconds: config.intervalSeconds,
                    isPaused: state.isPaused,
                    isActive: state.isActive
                )
                continue  // Skip normal countdown logic after reset
            }

            timerStates[type]?.remainingSeconds -= 1

            if let updatedState = timerStates[type], updatedState.remainingSeconds <= 0 {
                triggerReminder(for: type)
                break
            }
        }
    }

    func triggerReminder(for type: TimerType) {
        switch type {
        case .lookAway:
            pause()
            activeReminder = .lookAwayTriggered(
                countdownSeconds: settingsManager.settings.lookAwayCountdownSeconds)
        case .blink:
            activeReminder = .blinkTriggered
        case .posture:
            activeReminder = .postureTriggered
        }
    }

    func getTimeRemaining(for type: TimerType) -> TimeInterval {
        guard let state = timerStates[type] else { return 0 }
        return TimeInterval(state.remainingSeconds)
    }

    func getFormattedTimeRemaining(for type: TimerType) -> String {
        let seconds = Int(getTimeRemaining(for: type))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}
