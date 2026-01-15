//
//  MockSettingsManager.swift
//  GazeTests
//
//  A mock implementation of SettingsProviding for isolated unit testing.
//

import Combine
import Foundation
@testable import Gaze

/// A mock implementation of SettingsProviding that doesn't use UserDefaults.
/// This allows tests to run in complete isolation without affecting
/// the shared singleton or persisting data.
@MainActor
final class MockSettingsManager: ObservableObject, SettingsProviding {
    @Published var settings: AppSettings
    
    var settingsPublisher: Published<AppSettings>.Publisher {
        $settings
    }
    
    private let timerConfigKeyPaths: [TimerType: WritableKeyPath<AppSettings, TimerConfiguration>] = [
        .lookAway: \.lookAwayTimer,
        .blink: \.blinkTimer,
        .posture: \.postureTimer,
    ]
    
    /// Track method calls for verification in tests
    var saveCallCount = 0
    var loadCallCount = 0
    var resetToDefaultsCallCount = 0
    var saveImmediatelyCallCount = 0
    
    /// Track timer configuration updates for verification
    var timerConfigurationUpdates: [(TimerType, TimerConfiguration)] = []
    
    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }
    
    // MARK: - SettingsProviding conformance
    
    func timerConfiguration(for type: TimerType) -> TimerConfiguration {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }
    
    func updateTimerConfiguration(for type: TimerType, configuration: TimerConfiguration) {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = configuration
        timerConfigurationUpdates.append((type, configuration))
    }
    
    func allTimerConfigurations() -> [TimerType: TimerConfiguration] {
        var configs: [TimerType: TimerConfiguration] = [:]
        for (type, keyPath) in timerConfigKeyPaths {
            configs[type] = settings[keyPath: keyPath]
        }
        return configs
    }
    
    func save() {
        saveCallCount += 1
    }
    
    func saveImmediately() {
        saveImmediatelyCallCount += 1
    }
    
    func load() {
        loadCallCount += 1
    }
    
    func resetToDefaults() {
        resetToDefaultsCallCount += 1
        settings = .defaults
    }
    
    // MARK: - Test helper methods
    
    /// Resets all call tracking counters
    func resetCallTracking() {
        saveCallCount = 0
        loadCallCount = 0
        resetToDefaultsCallCount = 0
        saveImmediatelyCallCount = 0
        timerConfigurationUpdates = []
    }
    
    /// Creates settings with all timers enabled
    static func withAllTimersEnabled() -> MockSettingsManager {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = true
        settings.blinkTimer.enabled = true
        settings.postureTimer.enabled = true
        return MockSettingsManager(settings: settings)
    }
    
    /// Creates settings with all timers disabled
    static func withAllTimersDisabled() -> MockSettingsManager {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = false
        settings.blinkTimer.enabled = false
        settings.postureTimer.enabled = false
        return MockSettingsManager(settings: settings)
    }
    
    /// Creates settings with onboarding completed
    static func withOnboardingCompleted() -> MockSettingsManager {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        return MockSettingsManager(settings: settings)
    }
    
    /// Creates settings with custom timer intervals (in seconds)
    static func withTimerIntervals(
        lookAway: Int = 20 * 60,
        blink: Int = 7 * 60,
        posture: Int = 30 * 60
    ) -> MockSettingsManager {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.intervalSeconds = lookAway
        settings.blinkTimer.intervalSeconds = blink
        settings.postureTimer.intervalSeconds = posture
        return MockSettingsManager(settings: settings)
    }
    
    /// Enables a specific timer
    func enableTimer(_ type: TimerType) {
        guard let keyPath = timerConfigKeyPaths[type] else { return }
        settings[keyPath: keyPath].enabled = true
    }
    
    /// Disables a specific timer
    func disableTimer(_ type: TimerType) {
        guard let keyPath = timerConfigKeyPaths[type] else { return }
        settings[keyPath: keyPath].enabled = false
    }
    
    /// Sets a specific timer's interval
    func setTimerInterval(_ type: TimerType, seconds: Int) {
        guard let keyPath = timerConfigKeyPaths[type] else { return }
        settings[keyPath: keyPath].intervalSeconds = seconds
    }
    
    /// Adds a user timer
    func addUserTimer(_ timer: UserTimer) {
        settings.userTimers.append(timer)
    }
    
    /// Removes all user timers
    func clearUserTimers() {
        settings.userTimers = []
    }
}
