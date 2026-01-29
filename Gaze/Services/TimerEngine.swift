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

    private let settingsProvider: any SettingsProviding
    private let timeProvider: TimeProviding
    private let stateManager = TimerStateManager()
    private let scheduler: TimerScheduler
    private let reminderService: ReminderTriggerService
    private let configurationHelper: TimerConfigurationHelper
    private let smartModeCoordinator = SmartModeCoordinator()
    private var cancellables = Set<AnyCancellable>()

    convenience init(
        settingsManager: any SettingsProviding,
        enforceModeService: EnforceModeService? = nil
    ) {
        self.init(
            settingsManager: settingsManager,
            enforceModeService: enforceModeService,
            timeProvider: SystemTimeProvider()
        )
    }

    init(
        settingsManager: any SettingsProviding,
        enforceModeService: EnforceModeService?,
        timeProvider: TimeProviding
    ) {
        self.settingsProvider = settingsManager
        self.timeProvider = timeProvider
        self.scheduler = TimerScheduler(timeProvider: timeProvider)
        self.reminderService = ReminderTriggerService(
            settingsProvider: settingsManager,
            enforceModeService: enforceModeService ?? EnforceModeService.shared
        )
        self.configurationHelper = TimerConfigurationHelper(settingsProvider: settingsManager)

        Task { @MainActor in
            enforceModeService?.setTimerEngine(self)
        }

        scheduler.delegate = self
        smartModeCoordinator.delegate = self

        stateManager.$timerStates
            .sink { [weak self] states in
                self?.timerStates = states
            }
            .store(in: &cancellables)

        stateManager.$activeReminder
            .sink { [weak self] reminder in
                self?.activeReminder = reminder
            }
            .store(in: &cancellables)
    }

    func setupSmartMode(
        fullscreenService: FullscreenDetectionService?,
        idleService: IdleMonitoringService?
    ) {
        smartModeCoordinator.setup(
            fullscreenService: fullscreenService,
            idleService: idleService,
            settingsProvider: settingsProvider
        )
    }

    func pauseAllTimers(reason: PauseReason) {
        stateManager.pauseAll(reason: reason)
    }

    func resumeAllTimers(reason: PauseReason) {
        stateManager.resumeAll(reason: reason)
    }

    func start() {
        // If timers are already running, just update configurations without resetting
        if scheduler.isRunning {
            updateConfigurations()
            return
        }

        // Initial start - create all timer states
        stop()
        stateManager.initializeTimers(
            using: timerConfigurations(),
            userTimers: settingsProvider.settings.userTimers
        )
        scheduler.start()
    }

    /// Check if enforce mode is active and should affect timer behavior
    func checkEnforceMode() {
        // Deprecated - camera is now activated in handleTick before timer triggers
    }

    private func updateConfigurations() {
        logDebug("Updating timer configurations")
        stateManager.updateConfigurations(
            using: timerConfigurations(),
            userTimers: settingsProvider.settings.userTimers
        )
    }

    func stop() {
        scheduler.stop()
        stateManager.clearAll()
    }

    func pause() {
        stateManager.pauseAll(reason: .manual)
    }

    func resume() {
        stateManager.resumeAll(reason: .manual)
    }

    func pauseTimer(identifier: TimerIdentifier) {
        stateManager.pauseTimer(identifier: identifier, reason: .manual)
    }

    func resumeTimer(identifier: TimerIdentifier) {
        stateManager.resumeTimer(identifier: identifier, reason: .manual)
    }

    func skipNext(identifier: TimerIdentifier) {
        let intervalSeconds = getTimerInterval(for: identifier)
        stateManager.resetTimer(identifier: identifier, intervalSeconds: intervalSeconds)
    }

    /// Unified way to get interval for any timer type
    private func getTimerInterval(for identifier: TimerIdentifier) -> Int {
        configurationHelper.intervalSeconds(for: identifier)
    }

    func dismissReminder() {
        guard let reminder = activeReminder else { return }
        stateManager.setReminder(nil)

        let identifier = reminder.identifier
        skipNext(identifier: identifier)
        resumeTimer(identifier: identifier)

        reminderService.handleReminderDismissed()
    }

    private func handleTick() {
        for (identifier, state) in timerStates {
            guard !state.isPaused else { continue }
            guard state.isActive else { continue }

            if state.targetDate(using: timeProvider) < timeProvider.now() - 3.0 {
                skipNext(identifier: identifier)
                continue
            }

            guard let updatedState = stateManager.decrementTimer(identifier: identifier) else {
                continue
            }

            if reminderService.shouldPrepareEnforceMode(
                for: identifier,
                secondsRemaining: updatedState.remainingSeconds
            ) {
                Task { @MainActor in
                    await reminderService.prepareEnforceMode(
                        secondsRemaining: updatedState.remainingSeconds)
                }
            }

            if updatedState.remainingSeconds <= 0 {
                triggerReminder(for: identifier)
                break
            }
        }
    }

    func triggerReminder(for identifier: TimerIdentifier) {
        // Pause only the timer that triggered
        pauseTimer(identifier: identifier)

        if let reminder = reminderService.reminderEvent(for: identifier) {
            stateManager.setReminder(reminder)
        }
    }

    func getTimeRemaining(for identifier: TimerIdentifier) -> TimeInterval {
        stateManager.getTimeRemaining(for: identifier)
    }

    func getFormattedTimeRemaining(for identifier: TimerIdentifier) -> String {
        return getTimeRemaining(for: identifier).formatAsTimerDurationFull()
    }

    func isTimerPaused(_ identifier: TimerIdentifier) -> Bool {
        return stateManager.isTimerPaused(identifier)
    }

    private func timerConfigurations() -> [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)] {
        var configs: [TimerIdentifier: (enabled: Bool, intervalSeconds: Int)] = [:]
        for timerType in TimerType.allCases {
            if let config = configurationHelper.configuration(for: .builtIn(timerType)) {
                configs[.builtIn(timerType)] = config
            }
        }
        return configs
    }

}

extension TimerEngine: TimerSchedulerDelegate {
    func schedulerDidTick(_ scheduler: TimerScheduler) {
        handleTick()
    }
}

extension TimerEngine: SmartModeCoordinatorDelegate {
    func smartModeDidRequestPauseAll(_ coordinator: SmartModeCoordinator, reason: PauseReason) {
        pauseAllTimers(reason: reason)
    }

    func smartModeDidRequestResumeAll(_ coordinator: SmartModeCoordinator, reason: PauseReason) {
        resumeAllTimers(reason: reason)
    }
}
