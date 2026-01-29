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

    func initializeTimers(using configurations: [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)], userTimers: [UserTimer]) {
        timerStates = buildInitialStates(configurations: configurations, userTimers: userTimers)
    }

    func updateConfigurations(using configurations: [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)], userTimers: [UserTimer]) {
        timerStates = buildUpdatedStates(configurations: configurations, userTimers: userTimers)
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
        guard var state = timerStates[identifier] else { return }
        state.reset(intervalSeconds: intervalSeconds, keepPaused: true)
        timerStates[identifier] = state
    }

    func getTimeRemaining(for identifier: TimerIdentifier) -> TimeInterval {
        timerStates[identifier]?.remainingDuration ?? 0
    }

    func isTimerPaused(_ identifier: TimerIdentifier) -> Bool {
        return timerStates[identifier]?.isPaused ?? true
    }

    private func buildInitialStates(
        configurations: [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)],
        userTimers: [UserTimer]
    ) -> [TimerIdentifier: TimerState] {
        var newStates: [TimerIdentifier: TimerState] = [:]

        for (identifier, config) in configurations where config.enabled {
            newStates[identifier] = TimerStateBuilder.make(
                identifier: identifier,
                intervalSeconds: config.intervalSeconds
            )
        }

        for userTimer in userTimers where userTimer.enabled {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            newStates[identifier] = TimerStateBuilder.make(
                identifier: identifier,
                intervalSeconds: userTimer.intervalMinutes * 60
            )
        }

        return newStates
    }

    private func buildUpdatedStates(
        configurations: [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)],
        userTimers: [UserTimer]
    ) -> [TimerIdentifier: TimerState] {
        var newStates: [TimerIdentifier: TimerState] = [:]

        for (identifier, config) in configurations {
            guard config.enabled else { continue }
            newStates[identifier] = resolveState(
                identifier: identifier,
                intervalSeconds: config.intervalSeconds
            )
        }

        for userTimer in userTimers where userTimer.enabled {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            let intervalSeconds = userTimer.intervalMinutes * 60
            newStates[identifier] = resolveState(
                identifier: identifier,
                intervalSeconds: intervalSeconds
            )
        }

        return newStates
    }

    private func resolveState(identifier: TimerIdentifier, intervalSeconds: Int) -> TimerState {
        if var existingState = timerStates[identifier] {
            if existingState.originalIntervalSeconds != intervalSeconds {
                existingState.reset(intervalSeconds: intervalSeconds, keepPaused: true)
            }
            return existingState
        }

        return TimerStateBuilder.make(
            identifier: identifier,
            intervalSeconds: intervalSeconds
        )
    }

    func clearAll() {
        timerStates.removeAll()
        activeReminder = nil
    }
}
