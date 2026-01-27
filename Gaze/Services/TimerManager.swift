//
//  TimerManager.swift
//  Gaze
//
//  Manages timer creation, state updates, and lifecycle operations.
//

import Combine
import Foundation

@MainActor
class TimerManager: ObservableObject {
    @Published var timerStates: [TimerIdentifier: TimerState] = [:]
    
    private let settingsProvider: any SettingsProviding
    private var timerSubscription: AnyCancellable?
    private let timeProvider: TimeProviding
    
    init(
        settingsManager: any SettingsProviding,
        timeProvider: TimeProviding
    ) {
        self.settingsProvider = settingsManager
        self.timeProvider = timeProvider
    }
    
    func start() {
        // If timers are already running, just update configurations without resetting
        if timerSubscription != nil {
            updateConfigurations()
            return
        }
        
        // Initial start - create all timer states
        stop()
        
        var newStates: [TimerIdentifier: TimerState] = [:]
        
        // Add built-in timers (using unified approach)
        for timerType in TimerType.allCases {
            let config = settingsProvider.timerConfiguration(for: timerType)
            if config.enabled {
                let identifier = TimerIdentifier.builtIn(timerType)
                newStates[identifier] = TimerState(
                    identifier: identifier,
                    intervalSeconds: config.intervalSeconds,
                    isPaused: false,
                    isActive: true
                )
            }
        }
        
        // Add user timers (using unified approach)
        for userTimer in settingsProvider.settings.userTimers where userTimer.enabled {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            newStates[identifier] = TimerState(
                identifier: identifier,
                intervalSeconds: userTimer.intervalMinutes * 60,
                isPaused: false,
                isActive: true
            )
        }
        
        // Assign the entire dictionary at once to trigger @Published
        timerStates = newStates
        
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
    
    func updateConfigurations() {
        // Update configurations from settings
        var newStates: [TimerIdentifier: TimerState] = [:]
        
        // Update built-in timers (using unified approach)
        for timerType in TimerType.allCases {
            let config = settingsProvider.timerConfiguration(for: timerType)
            let identifier = TimerIdentifier.builtIn(timerType)
            
            if config.enabled {
                if let existingState = timerStates[identifier] {
                    // Timer exists - check if interval changed
                    if existingState.originalIntervalSeconds != config.intervalSeconds {
                        // Interval changed - reset with new interval
                        newStates[identifier] = TimerState(
                            identifier: identifier,
                            intervalSeconds: config.intervalSeconds,
                            isPaused: existingState.isPaused,
                            isActive: true
                        )
                    } else {
                        // Interval unchanged - keep existing state
                        newStates[identifier] = existingState
                    }
                } else {
                    // Timer was just enabled - create new state
                    newStates[identifier] = TimerState(
                        identifier: identifier,
                        intervalSeconds: config.intervalSeconds,
                        isPaused: false,
                        isActive: true
                    )
                }
            }
            // If config.enabled is false and timer exists, it will be removed
        }
        
        // Update user timers (using unified approach)
        for userTimer in settingsProvider.settings.userTimers {
            let identifier = TimerIdentifier.user(id: userTimer.id)
            let newIntervalSeconds = userTimer.intervalMinutes * 60
            
            if userTimer.enabled {
                if let existingState = timerStates[identifier] {
                    // Check if interval changed
                    if existingState.originalIntervalSeconds != newIntervalSeconds {
                        // Interval changed - reset with new interval
                        newStates[identifier] = TimerState(
                            identifier: identifier,
                            intervalSeconds: newIntervalSeconds,
                            isPaused: existingState.isPaused,
                            isActive: true
                        )
                    } else {
                        // Interval unchanged - keep existing state
                        newStates[identifier] = existingState
                    }
                } else {
                    // New timer - create state
                    newStates[identifier] = TimerState(
                        identifier: identifier,
                        intervalSeconds: newIntervalSeconds,
                        isPaused: false,
                        isActive: true
                    )
                }
            }
            // If timer is disabled, it will be removed
        }
        
        // Assign the entire dictionary at once to trigger @Published
        timerStates = newStates
    }
    
    private func handleTick() {
        for (identifier, state) in timerStates {
            guard !state.isPaused else { continue }
            guard state.isActive else { continue }
            
            if state.targetDate < timeProvider.now() - 3.0 {
                // Timer has expired but with some grace period
                continue
            }
            
            timerStates[identifier]?.remainingSeconds -= 1
            
            if let updatedState = timerStates[identifier] {
                // Update remaining seconds for the timer
                if updatedState.remainingSeconds <= 0 {
                    // This would normally trigger a reminder in a full implementation,
                    // but we're decomposing it to separate components
                }
            }
        }
    }
    
    func pause() {
        for (id, var state) in timerStates {
            state.pauseReasons.insert(.manual)
            state.isPaused = true
            timerStates[id] = state
        }
    }
    
    func resume() {
        for (id, var state) in timerStates {
            state.pauseReasons.remove(.manual)
            state.isPaused = !state.pauseReasons.isEmpty
            timerStates[id] = state
        }
    }
    
    func pauseTimer(identifier: TimerIdentifier) {
        guard var state = timerStates[identifier] else { return }
        state.pauseReasons.insert(.manual)
        state.isPaused = true
        timerStates[identifier] = state
    }
    
    func resumeTimer(identifier: TimerIdentifier) {
        guard var state = timerStates[identifier] else { return }
        state.pauseReasons.remove(.manual)
        state.isPaused = !state.pauseReasons.isEmpty
        timerStates[identifier] = state
    }
    
    func skipNext(identifier: TimerIdentifier) {
        guard let state = timerStates[identifier] else { return }
        
        // Unified approach to get interval - no more separate handling for user timers
        let intervalSeconds = getTimerInterval(for: identifier)
        
        timerStates[identifier] = TimerState(
            identifier: identifier,
            intervalSeconds: intervalSeconds,
            isPaused: state.isPaused,
            isActive: state.isActive
        )
    }
    
    /// Unified way to get interval for any timer type
    private func getTimerInterval(for identifier: TimerIdentifier) -> Int {
        switch identifier {
        case .builtIn(let type):
            let config = settingsProvider.timerConfiguration(for: type)
            return config.intervalSeconds
        case .user(let id):
            guard let userTimer = settingsProvider.settings.userTimers.first(where: { $0.id == id }) else {
                return 0
            }
            return userTimer.intervalMinutes * 60
        }
    }
    
    func getTimeRemaining(for identifier: TimerIdentifier) -> TimeInterval {
        guard let state = timerStates[identifier] else { return 0 }
        return TimeInterval(state.remainingSeconds)
    }
    
    func getFormattedTimeRemaining(for identifier: TimerIdentifier) -> String {
        return getTimeRemaining(for: identifier).formatAsTimerDurationFull()
    }
    
    func isTimerPaused(_ identifier: TimerIdentifier) -> Bool {
        return timerStates[identifier]?.isPaused ?? true
    }
}