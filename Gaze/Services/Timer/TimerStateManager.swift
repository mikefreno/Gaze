//
//  TimerStateManager.swift
//  Gaze
//
//  Manages timer state transitions and reminder state.
//

import Combine
import Foundation

@MainActor
final class TimerStateManager: ObservableObject {
    @Published private(set) var timerStates: [TimerIdentifier: TimerState] = [:]
    @Published private(set) var activeReminder: ReminderEvent?

    func initializeTimers(using configurations: [TimerIdentifier: TimerConfiguration], userTimers: [UserTimer]) {
        var newStates: [TimerIdentifier: TimerState] = [:]

        for (identifier, config) in configurations where config.enabled {
            newStates[identifier] = TimerState(
                identifier: identifier,
                intervalSeconds: config.intervalSeconds,
                isPaused: false,
                isActive: true
            )
        }

        for userTimer in userTimers where userTimer.enabled {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            newStates[identifier] = TimerState(
                identifier: identifier,
                intervalSeconds: userTimer.intervalMinutes * 60,
                isPaused: false,
                isActive: true
            )
        }

        timerStates = newStates
    }

    func updateConfigurations(using configurations: [TimerIdentifier: TimerConfiguration], userTimers: [UserTimer]) {
        var newStates: [TimerIdentifier: TimerState] = [:]

        for (identifier, config) in configurations {
            if config.enabled {
                if let existingState = timerStates[identifier] {
                    if existingState.originalIntervalSeconds != config.intervalSeconds {
                        newStates[identifier] = TimerState(
                            identifier: identifier,
                            intervalSeconds: config.intervalSeconds,
                            isPaused: existingState.isPaused,
                            isActive: true
                        )
                    } else {
                        newStates[identifier] = existingState
                    }
                } else {
                    newStates[identifier] = TimerState(
                        identifier: identifier,
                        intervalSeconds: config.intervalSeconds,
                        isPaused: false,
                        isActive: true
                    )
                }
            }
        }

        for userTimer in userTimers {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            let newIntervalSeconds = userTimer.intervalMinutes * 60

            if userTimer.enabled {
                if let existingState = timerStates[identifier] {
                    if existingState.originalIntervalSeconds != newIntervalSeconds {
                        newStates[identifier] = TimerState(
                            identifier: identifier,
                            intervalSeconds: newIntervalSeconds,
                            isPaused: existingState.isPaused,
                            isActive: true
                        )
                    } else {
                        newStates[identifier] = existingState
                    }
                } else {
                    newStates[identifier] = TimerState(
                        identifier: identifier,
                        intervalSeconds: newIntervalSeconds,
                        isPaused: false,
                        isActive: true
                    )
                }
            }
        }

        timerStates = newStates
    }

    func decrementTimer(identifier: TimerIdentifier) -> TimerState? {
        guard var state = timerStates[identifier] else { return nil }
        state.remainingSeconds -= 1
        timerStates[identifier] = state
        return state
    }

    func setReminder(_ reminder: ReminderEvent?) {
        activeReminder = reminder
    }

    func pauseAll(reason: PauseReason) {
        for (id, var state) in timerStates {
            state.pauseReasons.insert(reason)
            state.isPaused = true
            timerStates[id] = state
        }
    }

    func resumeAll(reason: PauseReason) {
        for (id, var state) in timerStates {
            state.pauseReasons.remove(reason)
            state.isPaused = !state.pauseReasons.isEmpty
            timerStates[id] = state
        }
    }

    func pauseTimer(identifier: TimerIdentifier, reason: PauseReason) {
        guard var state = timerStates[identifier] else { return }
        state.pauseReasons.insert(reason)
        state.isPaused = true
        timerStates[identifier] = state
    }

    func resumeTimer(identifier: TimerIdentifier, reason: PauseReason) {
        guard var state = timerStates[identifier] else { return }
        state.pauseReasons.remove(reason)
        state.isPaused = !state.pauseReasons.isEmpty
        timerStates[identifier] = state
    }

    func resetTimer(identifier: TimerIdentifier, intervalSeconds: Int) {
        guard let state = timerStates[identifier] else { return }
        timerStates[identifier] = TimerState(
            identifier: identifier,
            intervalSeconds: intervalSeconds,
            isPaused: state.isPaused,
            isActive: state.isActive
        )
    }

    func getTimeRemaining(for identifier: TimerIdentifier) -> TimeInterval {
        guard let state = timerStates[identifier] else { return 0 }
        return TimeInterval(state.remainingSeconds)
    }

    func isTimerPaused(_ identifier: TimerIdentifier) -> Bool {
        return timerStates[identifier]?.isPaused ?? true
    }

    func clearAll() {
        timerStates.removeAll()
        activeReminder = nil
    }
}
