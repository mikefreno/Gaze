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
    @Published var timerStates: [TimerIdentifier: TimerState] = [:]
    @Published var activeReminder: ReminderEvent?

    private var timerSubscription: AnyCancellable?
    private let settingsManager: SettingsManager
    private var sleepStartTime: Date?
    
    // For enforce mode integration
    private var enforceModeService: EnforceModeService?
    
    // Smart Mode services
    private var fullscreenService: FullscreenDetectionService?
    private var idleService: IdleMonitoringService?
    private var cancellables = Set<AnyCancellable>()

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        self.enforceModeService = EnforceModeService.shared
        
        Task { @MainActor in
            self.enforceModeService?.setTimerEngine(self)
        }
    }
    
    func setupSmartMode(
        fullscreenService: FullscreenDetectionService?,
        idleService: IdleMonitoringService?
    ) {
        self.fullscreenService = fullscreenService
        self.idleService = idleService
        
        // Subscribe to fullscreen state changes
        fullscreenService?.$isFullscreenActive
            .sink { [weak self] isFullscreen in
                Task { @MainActor in
                    self?.handleFullscreenChange(isFullscreen: isFullscreen)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to idle state changes
        idleService?.$isIdle
            .sink { [weak self] isIdle in
                Task { @MainActor in
                    self?.handleIdleChange(isIdle: isIdle)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleFullscreenChange(isFullscreen: Bool) {
        guard settingsManager.settings.smartMode.autoPauseOnFullscreen else { return }
        
        if isFullscreen {
            pauseAllTimers(reason: .fullscreen)
            print("⏸️ Timers paused: fullscreen detected")
        } else {
            resumeAllTimers(reason: .fullscreen)
            print("▶️ Timers resumed: fullscreen exited")
        }
    }
    
    private func handleIdleChange(isIdle: Bool) {
        guard settingsManager.settings.smartMode.autoPauseOnIdle else { return }
        
        if isIdle {
            pauseAllTimers(reason: .idle)
            print("⏸️ Timers paused: user idle")
        } else {
            resumeAllTimers(reason: .idle)
            print("▶️ Timers resumed: user active")
        }
    }
    
    private func pauseAllTimers(reason: PauseReason) {
        for (id, var state) in timerStates {
            state.pauseReasons.insert(reason)
            state.isPaused = true
            timerStates[id] = state
        }
    }
    
    private func resumeAllTimers(reason: PauseReason) {
        for (id, var state) in timerStates {
            state.pauseReasons.remove(reason)
            state.isPaused = !state.pauseReasons.isEmpty
            timerStates[id] = state
        }
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
        
        // Add built-in timers
        for timerType in TimerType.allCases {
            let config = settingsManager.timerConfiguration(for: timerType)
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
        
        // Add user timers
        for userTimer in settingsManager.settings.userTimers where userTimer.enabled {
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
    
    /// Check if enforce mode is active and should affect timer behavior
    func checkEnforceMode() {
        // Deprecated - camera is now activated in handleTick before timer triggers
    }
    
    private func updateConfigurations() {
        var newStates: [TimerIdentifier: TimerState] = [:]
        
        // Update built-in timers
        for timerType in TimerType.allCases {
            let config = settingsManager.timerConfiguration(for: timerType)
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
        
        // Update user timers
        for userTimer in settingsManager.settings.userTimers {
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

    func stop() {
        timerSubscription?.cancel()
        timerSubscription = nil
        timerStates.removeAll()
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
        
        let intervalSeconds: Int
        switch identifier {
        case .builtIn(let type):
            let config = settingsManager.timerConfiguration(for: type)
            intervalSeconds = config.intervalSeconds
        case .user(let id):
            guard let userTimer = settingsManager.settings.userTimers.first(where: { $0.id == id }) else { return }
            intervalSeconds = userTimer.intervalMinutes * 60
        }
        
        timerStates[identifier] = TimerState(
            identifier: identifier,
            intervalSeconds: intervalSeconds,
            isPaused: state.isPaused,
            isActive: state.isActive
        )
    }

    func dismissReminder() {
        guard let reminder = activeReminder else { return }
        activeReminder = nil

        let identifier = reminder.identifier
        skipNext(identifier: identifier)
        resumeTimer(identifier: identifier)
        
        enforceModeService?.handleReminderDismissed()
    }

    private func handleTick() {
        for (identifier, state) in timerStates {
            guard !state.isPaused else { continue }
            guard state.isActive else { continue }
            
            if state.targetDate < Date() - 3.0 {
                skipNext(identifier: identifier)
                continue
            }

            timerStates[identifier]?.remainingSeconds -= 1

            if let updatedState = timerStates[identifier] {
                if updatedState.remainingSeconds <= 3 && !updatedState.isPaused {
                    if case .builtIn(.lookAway) = identifier {
                        if enforceModeService?.shouldEnforceBreak(for: identifier) == true {
                            Task { @MainActor in
                                await enforceModeService?.startCameraForLookawayTimer(secondsRemaining: updatedState.remainingSeconds)
                            }
                        }
                    }
                }
                
                if updatedState.remainingSeconds <= 0 {
                    triggerReminder(for: identifier)
                    break
                }
            }
        }
    }

    func triggerReminder(for identifier: TimerIdentifier) {
        // Pause only the timer that triggered
        pauseTimer(identifier: identifier)
        
        switch identifier {
        case .builtIn(let type):
            switch type {
            case .lookAway:
                activeReminder = .lookAwayTriggered(
                    countdownSeconds: settingsManager.settings.lookAwayCountdownSeconds)
            case .blink:
                activeReminder = .blinkTriggered
            case .posture:
                activeReminder = .postureTriggered
            }
        case .user(let id):
            if let userTimer = settingsManager.settings.userTimers.first(where: { $0.id == id }) {
                activeReminder = .userTimerTriggered(userTimer)
            }
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
    
    /// Handles system sleep event
    /// - Saves current time for elapsed calculation
    /// - Pauses all active timers
    func handleSystemSleep() {
        sleepStartTime = Date()
        for (id, var state) in timerStates {
            state.pauseReasons.insert(.system)
            state.isPaused = true
            timerStates[id] = state
        }
    }
    
    /// Handles system wake event
    /// - Calculates elapsed time during sleep
    /// - Adjusts remaining time for all active timers
    /// - Timers that expired during sleep will trigger immediately (1s delay)
    /// - Resumes all timers
    func handleSystemWake() {
        guard let sleepStart = sleepStartTime else {
            return
        }
        
        defer {
            sleepStartTime = nil
        }
        
        let elapsedSeconds = Int(Date().timeIntervalSince(sleepStart))
        
        guard elapsedSeconds >= 1 else {
            for (id, var state) in timerStates {
                state.pauseReasons.remove(.system)
                state.isPaused = !state.pauseReasons.isEmpty
                timerStates[id] = state
            }
            return
        }
        
        for (identifier, state) in timerStates where state.isActive {
            var updatedState = state
            updatedState.remainingSeconds = max(0, state.remainingSeconds - elapsedSeconds)
            
            if updatedState.remainingSeconds <= 0 {
                updatedState.remainingSeconds = 1
            }
            
            updatedState.pauseReasons.remove(.system)
            updatedState.isPaused = !updatedState.pauseReasons.isEmpty
            timerStates[identifier] = updatedState
        }
    }
}
