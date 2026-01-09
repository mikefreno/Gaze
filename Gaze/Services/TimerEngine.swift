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
    
    // Track user timer states separately
    private var userTimerStates: [String: TimerState] = [:]

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

        // Start user timers
        for userTimer in settingsManager.settings.userTimers {
            startUserTimer(userTimer)
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
        userTimerStates.removeAll()
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

        // Handle regular timers first
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
        
        // Handle user timers
        handleUserTimerTicks()
    }
    
    private func handleUserTimerTicks() {
        for (id, state) in userTimerStates {
            if !state.isActive || state.isPaused { continue }
            
            // Update user timer countdown
            userTimerStates[id]?.remainingSeconds -= 1
            
            if let updatedState = userTimerStates[id], updatedState.remainingSeconds <= 0 {
                // Trigger the user timer reminder
                triggerUserTimerReminder(forId: id)
            }
        }
    }
    
    private func triggerUserTimerReminder(forId id: String) {
        // Here we'd implement how to show a subtle reminder for user timers
        // For now, just reset the timer
        if let userTimer = settingsManager.settings.userTimers.first(where: { $0.id == id }) {
            userTimerStates[id] = TimerState(
                type: .lookAway, // Placeholder - user timers won't use this
                intervalSeconds: userTimer.timeOnScreenSeconds,
                isPaused: false,
                isActive: true
            )
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
    
    // User timer management methods
    func startUserTimer(_ userTimer: UserTimer) {
        userTimerStates[userTimer.id] = TimerState(
            type: .lookAway, // Placeholder - we'll need to make this more flexible
            intervalSeconds: userTimer.timeOnScreenSeconds,
            isPaused: false,
            isActive: true
        )
    }
    
    func stopUserTimer(_ userTimerId: String) {
        userTimerStates[userTimerId] = nil
    }
    
    func pauseUserTimer(_ userTimerId: String) {
        if var state = userTimerStates[userTimerId] {
            state.isPaused = true
            userTimerStates[userTimerId] = state
        }
    }
    
    func resumeUserTimer(_ userTimerId: String) {
        if var state = userTimerStates[userTimerId] {
            state.isPaused = false
            userTimerStates[userTimerId] = state
        }
    }

    func getTimeRemaining(for type: TimerType) -> TimeInterval {
        guard let state = timerStates[type] else { return 0 }
        return TimeInterval(state.remainingSeconds)
    }
    
    func getUserTimeRemaining(for userId: String) -> TimeInterval {
        guard let state = userTimerStates[userId] else { return 0 }
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
    
    func getUserFormattedTimeRemaining(for userId: String) -> String {
        let seconds = Int(getUserTimeRemaining(for: userId))
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
