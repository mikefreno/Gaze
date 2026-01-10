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
        print("🎯 [TimerEngine] start() called, subscription exists: \(timerSubscription != nil)")
        
        // If timers are already running, just update configurations without resetting
        if timerSubscription != nil {
            print("🎯 [TimerEngine] Updating existing configurations")
            updateConfigurations()
            return
        }
        
        print("🎯 [TimerEngine] Initial start - creating all timer states")
        
        // Initial start - create all timer states
        stop()

        var newStates: [TimerType: TimerState] = [:]
        
        for timerType in TimerType.allCases {
            let config = settingsManager.timerConfiguration(for: timerType)
            if config.enabled {
                newStates[timerType] = TimerState(
                    type: timerType,
                    intervalSeconds: config.intervalSeconds,
                    isPaused: false,
                    isActive: true
                )
                print("🎯 [TimerEngine] Created state for \(timerType.displayName): \(config.intervalSeconds)s")
            }
        }
        
        // Assign the entire dictionary at once to trigger @Published
        timerStates = newStates
        print("🎯 [TimerEngine] Assigned \(newStates.count) timer states")

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
    
    private func updateConfigurations() {
        print("🔄 [TimerEngine] updateConfigurations() called")
        print("🔄 [TimerEngine] Current timerStates keys: \(timerStates.keys.map { $0.displayName })")
        var newStates: [TimerType: TimerState] = [:]
        
        for timerType in TimerType.allCases {
            let config = settingsManager.timerConfiguration(for: timerType)
            print("🔄 [TimerEngine] Processing \(timerType.displayName): enabled=\(config.enabled), intervalSeconds=\(config.intervalSeconds)")
            
            if config.enabled {
                if let existingState = timerStates[timerType] {
                    // Timer exists - check if interval changed
                    print("🔄 [TimerEngine] \(timerType.displayName) exists in current states")
                    if existingState.originalIntervalSeconds != config.intervalSeconds {
                        // Interval changed - reset with new interval
                        print("🔄 [TimerEngine] \(timerType.displayName) interval changed: \(existingState.originalIntervalSeconds)s -> \(config.intervalSeconds)s, resetting")
                        newStates[timerType] = TimerState(
                            type: timerType,
                            intervalSeconds: config.intervalSeconds,
                            isPaused: existingState.isPaused,
                            isActive: true
                        )
                    } else {
                        // Interval unchanged - keep existing state
                        print("🔄 [TimerEngine] \(timerType.displayName) unchanged, keeping state (remaining: \(existingState.remainingSeconds)s)")
                        newStates[timerType] = existingState
                    }
                } else {
                    // Timer was just enabled - create new state
                    print("🔄 [TimerEngine] \(timerType.displayName) NOT in current states, newly enabled, creating state")
                    newStates[timerType] = TimerState(
                        type: timerType,
                        intervalSeconds: config.intervalSeconds,
                        isPaused: false,
                        isActive: true
                    )
                }
            } else {
                if timerStates[timerType] != nil {
                    print("🔄 [TimerEngine] \(timerType.displayName) disabled, removing state")
                } else {
                    print("🔄 [TimerEngine] \(timerType.displayName) disabled and not in current states")
                }
            }
            // If config.enabled is false and timer exists, it will be removed
        }
        
        print("🔄 [TimerEngine] New states keys: \(newStates.keys.map { $0.displayName })")
        print("🔄 [TimerEngine] Assigning \(newStates.count) timer states (was \(timerStates.count))")
        // Assign the entire dictionary at once to trigger @Published
        timerStates = newStates
        
        // Update user timers
        updateUserTimers()
    }
    
    private func updateUserTimers() {
        let currentTimerIds = Set(userTimerStates.keys)
        let newTimerIds = Set(settingsManager.settings.userTimers.map { $0.id })
        
        // Remove timers that no longer exist
        let removedIds = currentTimerIds.subtracting(newTimerIds)
        for id in removedIds {
            userTimerStates.removeValue(forKey: id)
        }
        
        // Add or update timers
        for userTimer in settingsManager.settings.userTimers {
            if let existingState = userTimerStates[userTimer.id] {
                // Check if interval changed
                if existingState.originalIntervalSeconds != userTimer.timeOnScreenSeconds {
                    // Interval changed - reset with new interval
                    userTimerStates[userTimer.id] = TimerState(
                        type: .lookAway, // Placeholder
                        intervalSeconds: userTimer.timeOnScreenSeconds,
                        isPaused: existingState.isPaused,
                        isActive: userTimer.enabled
                    )
                } else {
                    // Just update enabled state if needed
                    var state = existingState
                    state.isActive = userTimer.enabled
                    userTimerStates[userTimer.id] = state
                }
            } else {
                // New timer - create state
                startUserTimer(userTimer)
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
