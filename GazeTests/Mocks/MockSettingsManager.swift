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
    
    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }
    
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
        saveCallCount += 1
    }
    
    func load() {
        loadCallCount += 1
    }
    
    func resetToDefaults() {
        resetToDefaultsCallCount += 1
        settings = .defaults
    }
}
