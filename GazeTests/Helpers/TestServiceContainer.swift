//
//  TestServiceContainer.swift
//  GazeTests
//
//  Test-specific dependency injection container.
//

import Foundation
@testable import Gaze

/// A dependency injection container configured for testing.
/// Provides injectable dependencies and test-specific utilities.
@MainActor
final class TestServiceContainer {
    /// The settings manager instance
    private(set) var settingsManager: any SettingsProviding
    
    /// The timer engine instance
    private var _timerEngine: TimerEngine?
    
    /// Time provider for deterministic testing
    let timeProvider: TimeProviding
    
    /// Creates a test container with default mock settings
    convenience init() {
        self.init(settings: AppSettings())
    }
    
    /// Creates a test container with custom settings
    init(settings: AppSettings) {
        self.settingsManager = EnhancedMockSettingsManager(settings: settings)
        self.timeProvider = MockTimeProvider()
    }
    
    /// Creates a test container with a custom settings manager
    init(settingsManager: any SettingsProviding) {
        self.settingsManager = settingsManager
        self.timeProvider = MockTimeProvider()
    }
    
    /// Gets or creates the timer engine for testing
    var timerEngine: TimerEngine {
        if let engine = _timerEngine {
            return engine
        }
        let engine = TimerEngine(
            settingsManager: settingsManager,
            enforceModeService: nil,
            timeProvider: timeProvider
        )
        _timerEngine = engine
        return engine
    }
    
    /// Sets a custom timer engine
    func setTimerEngine(_ engine: TimerEngine) {
        _timerEngine = engine
    }
    
    /// Resets the container for test isolation
    func reset() {
        _timerEngine?.stop()
        _timerEngine = nil
    }
}
