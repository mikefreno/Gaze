//
//  IntegrationTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

@MainActor
final class IntegrationTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    var timerEngine: TimerEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        settingsManager = SettingsManager.shared
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        settingsManager.load()
        timerEngine = TimerEngine(settingsManager: settingsManager)
    }
    
    override func tearDown() async throws {
        timerEngine.stop()
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        try await super.tearDown()
    }
    
    func testSettingsChangePropagateToTimerEngine() {
        timerEngine.start()
        
        let originalInterval = timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds
        XCTAssertEqual(originalInterval, 20 * 60)
        
        let newConfig = TimerConfiguration(enabled: true, intervalSeconds: 10 * 60)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: newConfig)
        
        timerEngine.start()
        
        let newInterval = timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds
        XCTAssertEqual(newInterval, 10 * 60)
    }
    
    func testDisablingTimerRemovesFromEngine() {
        settingsManager.settings.blinkTimer.enabled = true
        timerEngine.start()
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.blink)])
        
        // Stop and restart to apply the disabled setting
        timerEngine.stop()
        settingsManager.settings.blinkTimer.enabled = false
        timerEngine.start()
        XCTAssertNil(timerEngine.timerStates[.builtIn(.blink)])
    }
    
    func testEnablingTimerAddsToEngine() {
        settingsManager.settings.postureTimer.enabled = false
        timerEngine.start()
        XCTAssertNil(timerEngine.timerStates[.builtIn(.posture)])
        
        let config = TimerConfiguration(enabled: true, intervalSeconds: 30 * 60)
        settingsManager.updateTimerConfiguration(for: .posture, configuration: config)
        
        timerEngine.start()
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.posture)])
    }
    
    func testSettingsPersistAcrossEngineLifecycle() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 15 * 60)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        timerEngine.start()
        timerEngine.stop()
        
        let newEngine = TimerEngine(settingsManager: settingsManager)
        newEngine.start()
        
        XCTAssertNil(newEngine.timerStates[.builtIn(.lookAway)])
    }
    
    func testMultipleTimerConfigurationUpdates() {
        timerEngine.start()
        
        let configs = [
            (TimerType.lookAway, TimerConfiguration(enabled: true, intervalSeconds: 600)),
            (TimerType.blink, TimerConfiguration(enabled: true, intervalSeconds: 300)),
            (TimerType.posture, TimerConfiguration(enabled: true, intervalSeconds: 1800))
        ]
        
        for (type, config) in configs {
            settingsManager.updateTimerConfiguration(for: type, configuration: config)
        }
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds, 600)
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.blink)]?.remainingSeconds, 300)
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.posture)]?.remainingSeconds, 1800)
    }
    
    func testResetToDefaultsAffectsTimerEngine() {
        // Blink is disabled by default, enable it first
        settingsManager.settings.blinkTimer.enabled = true
        timerEngine.start()
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.blink)])
        
        // Reset to defaults (blink disabled)
        timerEngine.stop()
        settingsManager.resetToDefaults()
        timerEngine.start()
        
        // Blink should now be disabled (per defaults)
        XCTAssertNil(timerEngine.timerStates[.builtIn(.blink)])
    }
    
    func testTimerEngineRespectsDisabledTimers() {
        settingsManager.settings.lookAwayTimer.enabled = false
        settingsManager.settings.blinkTimer.enabled = false
        settingsManager.settings.postureTimer.enabled = false
        
        timerEngine.start()
        
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testCompleteWorkflow() {
        // Enable all timers for this test
        settingsManager.settings.blinkTimer.enabled = true
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 3)
        
        timerEngine.pause()
        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }
        
        timerEngine.resume()
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
        
        timerEngine.skipNext(identifier: .builtIn(.lookAway))
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds, 20 * 60)
        
        timerEngine.stop()
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testReminderWorkflow() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .builtIn(.lookAway))
        XCTAssertNotNil(timerEngine.activeReminder)
        
        // Only the triggered timer should be paused
        XCTAssertTrue(timerEngine.isTimerPaused(.builtIn(.lookAway)))
        
        timerEngine.dismissReminder()
        XCTAssertNil(timerEngine.activeReminder)
        
        // The triggered timer should be resumed
        XCTAssertFalse(timerEngine.isTimerPaused(.builtIn(.lookAway)))
    }
    
    func testSettingsAutoSaveIntegration() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 900)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        // Force save to persist immediately (settings debounce by 500ms normally)
        settingsManager.save()
        settingsManager.load()
        
        let loadedConfig = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertEqual(loadedConfig.intervalSeconds, 900)
        XCTAssertFalse(loadedConfig.enabled)
    }
}
