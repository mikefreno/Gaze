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
        
        let originalInterval = timerEngine.timerStates[.lookAway]?.remainingSeconds
        XCTAssertEqual(originalInterval, 20 * 60)
        
        let newConfig = TimerConfiguration(enabled: true, intervalSeconds: 10 * 60)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: newConfig)
        
        timerEngine.start()
        
        let newInterval = timerEngine.timerStates[.lookAway]?.remainingSeconds
        XCTAssertEqual(newInterval, 10 * 60)
    }
    
    func testDisablingTimerRemovesFromEngine() {
        timerEngine.start()
        XCTAssertNotNil(timerEngine.timerStates[.blink])
        
        var config = TimerConfiguration(enabled: false, intervalSeconds: 5 * 60)
        settingsManager.updateTimerConfiguration(for: .blink, configuration: config)
        
        timerEngine.start()
        XCTAssertNil(timerEngine.timerStates[.blink])
    }
    
    func testEnablingTimerAddsToEngine() {
        settingsManager.settings.postureTimer.enabled = false
        timerEngine.start()
        XCTAssertNil(timerEngine.timerStates[.posture])
        
        let config = TimerConfiguration(enabled: true, intervalSeconds: 30 * 60)
        settingsManager.updateTimerConfiguration(for: .posture, configuration: config)
        
        timerEngine.start()
        XCTAssertNotNil(timerEngine.timerStates[.posture])
    }
    
    func testSettingsPersistAcrossEngineLifecycle() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 15 * 60)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        timerEngine.start()
        timerEngine.stop()
        
        let newEngine = TimerEngine(settingsManager: settingsManager)
        newEngine.start()
        
        XCTAssertNil(newEngine.timerStates[.lookAway])
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
        
        XCTAssertEqual(timerEngine.timerStates[.lookAway]?.remainingSeconds, 600)
        XCTAssertEqual(timerEngine.timerStates[.blink]?.remainingSeconds, 300)
        XCTAssertEqual(timerEngine.timerStates[.posture]?.remainingSeconds, 1800)
    }
    
    func testResetToDefaultsAffectsTimerEngine() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 5 * 60)
        settingsManager.updateTimerConfiguration(for: .blink, configuration: config)
        
        timerEngine.start()
        XCTAssertNil(timerEngine.timerStates[.blink])
        
        settingsManager.resetToDefaults()
        timerEngine.start()
        
        XCTAssertNotNil(timerEngine.timerStates[.blink])
        XCTAssertEqual(timerEngine.timerStates[.blink]?.remainingSeconds, 5 * 60)
    }
    
    func testTimerEngineRespectsDisabledTimers() {
        settingsManager.settings.lookAwayTimer.enabled = false
        settingsManager.settings.blinkTimer.enabled = false
        settingsManager.settings.postureTimer.enabled = false
        
        timerEngine.start()
        
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testCompleteWorkflow() {
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
        
        timerEngine.skipNext(type: .lookAway)
        XCTAssertEqual(timerEngine.timerStates[.lookAway]?.remainingSeconds, 20 * 60)
        
        timerEngine.stop()
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testReminderWorkflow() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .lookAway)
        XCTAssertNotNil(timerEngine.activeReminder)
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }
        
        timerEngine.dismissReminder()
        XCTAssertNil(timerEngine.activeReminder)
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }
    
    func testSettingsAutoSaveIntegration() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 900)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        settingsManager.load()
        
        let loadedConfig = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertEqual(loadedConfig.intervalSeconds, 900)
        XCTAssertFalse(loadedConfig.enabled)
    }
}
