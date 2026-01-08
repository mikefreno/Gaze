//
//  SettingsManagerTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/7/26.
//

import XCTest
@testable import Gaze

@MainActor
final class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        settingsManager = SettingsManager.shared
        // Clear any existing settings
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        settingsManager.load()
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        try await super.tearDown()
    }
    
    func testDefaultSettings() {
        let defaults = AppSettings.defaults
        
        XCTAssertTrue(defaults.lookAwayTimer.enabled)
        XCTAssertEqual(defaults.lookAwayTimer.intervalSeconds, 20 * 60)
        XCTAssertEqual(defaults.lookAwayCountdownSeconds, 20)
        
        XCTAssertTrue(defaults.blinkTimer.enabled)
        XCTAssertEqual(defaults.blinkTimer.intervalSeconds, 5 * 60)
        
        XCTAssertTrue(defaults.postureTimer.enabled)
        XCTAssertEqual(defaults.postureTimer.intervalSeconds, 30 * 60)
        
        XCTAssertFalse(defaults.hasCompletedOnboarding)
        XCTAssertFalse(defaults.launchAtLogin)
        XCTAssertTrue(defaults.playSounds)
    }
    
    func testSaveAndLoad() {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = false
        settings.lookAwayCountdownSeconds = 30
        settings.hasCompletedOnboarding = true
        
        settingsManager.settings = settings
        
        settingsManager.load()
        
        XCTAssertFalse(settingsManager.settings.lookAwayTimer.enabled)
        XCTAssertEqual(settingsManager.settings.lookAwayCountdownSeconds, 30)
        XCTAssertTrue(settingsManager.settings.hasCompletedOnboarding)
    }
    
    func testTimerConfigurationRetrieval() {
        let lookAwayConfig = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertTrue(lookAwayConfig.enabled)
        XCTAssertEqual(lookAwayConfig.intervalSeconds, 20 * 60)
        
        let blinkConfig = settingsManager.timerConfiguration(for: .blink)
        XCTAssertTrue(blinkConfig.enabled)
        XCTAssertEqual(blinkConfig.intervalSeconds, 5 * 60)
        
        let postureConfig = settingsManager.timerConfiguration(for: .posture)
        XCTAssertTrue(postureConfig.enabled)
        XCTAssertEqual(postureConfig.intervalSeconds, 30 * 60)
    }
    
    func testUpdateTimerConfiguration() {
        var newConfig = TimerConfiguration(enabled: false, intervalSeconds: 10 * 60)
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: newConfig)
        
        let retrieved = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertFalse(retrieved.enabled)
        XCTAssertEqual(retrieved.intervalSeconds, 10 * 60)
    }
    
    func testResetToDefaults() {
        settingsManager.settings.lookAwayTimer.enabled = false
        settingsManager.settings.hasCompletedOnboarding = true
        
        settingsManager.resetToDefaults()
        
        XCTAssertTrue(settingsManager.settings.lookAwayTimer.enabled)
        XCTAssertFalse(settingsManager.settings.hasCompletedOnboarding)
    }
    
    func testCodableEncoding() {
        let settings = AppSettings.defaults
        
        let encoder = JSONEncoder()
        let data = try? encoder.encode(settings)
        
        XCTAssertNotNil(data)
    }
    
    func testCodableDecoding() {
        let settings = AppSettings.defaults
        
        let encoder = JSONEncoder()
        let data = try! encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(AppSettings.self, from: data)
        
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded, settings)
    }
    
    func testTimerConfigurationIntervalMinutes() {
        var config = TimerConfiguration(enabled: true, intervalSeconds: 600)
        
        XCTAssertEqual(config.intervalMinutes, 10)
        
        config.intervalMinutes = 20
        XCTAssertEqual(config.intervalSeconds, 1200)
    }
}
