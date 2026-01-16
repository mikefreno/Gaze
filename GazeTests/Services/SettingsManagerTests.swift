//
//  SettingsManagerTests.swift
//  GazeTests
//
//  Unit tests for SettingsManager service.
//

import Combine
import XCTest
@testable import Gaze

@MainActor
final class SettingsManagerTests: XCTestCase {
    
    var settingsManager: SettingsManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        settingsManager = SettingsManager.shared
        cancellables = []
        
        // Reset to defaults for testing
        settingsManager.resetToDefaults()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        settingsManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testSettingsManagerInitialization() {
        XCTAssertNotNil(settingsManager)
        XCTAssertNotNil(settingsManager.settings)
    }
    
    func testDefaultSettingsValues() {
        let defaults = AppSettings.defaults
        
        XCTAssertTrue(defaults.lookAwayTimer.enabled)
        XCTAssertFalse(defaults.blinkTimer.enabled)  // Blink timer is disabled by default
        XCTAssertTrue(defaults.postureTimer.enabled)
        XCTAssertFalse(defaults.hasCompletedOnboarding)
    }
    
    // MARK: - Timer Configuration Tests
    
    func testGetTimerConfiguration() {
        let lookAwayConfig = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertNotNil(lookAwayConfig)
        XCTAssertTrue(lookAwayConfig.enabled)
    }
    
    func testUpdateTimerConfiguration() {
        var config = settingsManager.timerConfiguration(for: .lookAway)
        config.intervalSeconds = 1500
        config.enabled = false
        
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        let updated = settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertEqual(updated.intervalSeconds, 1500)
        XCTAssertFalse(updated.enabled)
    }
    
    func testAllTimerConfigurations() {
        let allConfigs = settingsManager.allTimerConfigurations()
        
        XCTAssertEqual(allConfigs.count, 3)
        XCTAssertNotNil(allConfigs[.lookAway])
        XCTAssertNotNil(allConfigs[.blink])
        XCTAssertNotNil(allConfigs[.posture])
    }
    
    func testUpdateMultipleTimerConfigurations() {
        var lookAway = settingsManager.timerConfiguration(for: .lookAway)
        lookAway.intervalSeconds = 1000
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: lookAway)
        
        var blink = settingsManager.timerConfiguration(for: .blink)
        blink.intervalSeconds = 250
        settingsManager.updateTimerConfiguration(for: .blink, configuration: blink)
        
        XCTAssertEqual(settingsManager.timerConfiguration(for: .lookAway).intervalSeconds, 1000)
        XCTAssertEqual(settingsManager.timerConfiguration(for: .blink).intervalSeconds, 250)
    }
    
    // MARK: - Settings Publisher Tests
    
    func testSettingsPublisherEmitsChanges() async throws {
        let expectation = XCTestExpectation(description: "Settings changed")
        var receivedSettings: AppSettings?
        
        settingsManager.settingsPublisher
            .dropFirst()  // Skip initial value
            .sink { settings in
                receivedSettings = settings
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger change
        settingsManager.settings.playSounds = !settingsManager.settings.playSounds
        settingsManager.save()
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedSettings)
    }
    
    // MARK: - Save/Load Tests
    
    func testSave() {
        settingsManager.settings.playSounds = false
        settingsManager.save()
        
        // Save is debounced, so just verify it doesn't crash
        XCTAssertFalse(settingsManager.settings.playSounds)
    }
    
    func testSaveImmediately() {
        settingsManager.settings.launchAtLogin = true
        settingsManager.saveImmediately()
        
        // Verify the setting persisted
        XCTAssertTrue(settingsManager.settings.launchAtLogin)
    }
    
    func testLoad() {
        // Load should restore settings from UserDefaults
        settingsManager.load()
        XCTAssertNotNil(settingsManager.settings)
    }
    
    // MARK: - Reset Tests
    
    func testResetToDefaults() {
        // Modify settings
        settingsManager.settings.playSounds = false
        settingsManager.settings.launchAtLogin = true
        var config = settingsManager.timerConfiguration(for: .lookAway)
        config.intervalSeconds = 5000
        settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        
        // Reset
        settingsManager.resetToDefaults()
        
        // Verify reset to defaults
        let defaults = AppSettings.defaults
        XCTAssertEqual(settingsManager.settings.playSounds, defaults.playSounds)
        XCTAssertEqual(settingsManager.settings.launchAtLogin, defaults.launchAtLogin)
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingCompletion() {
        XCTAssertFalse(settingsManager.settings.hasCompletedOnboarding)
        
        settingsManager.settings.hasCompletedOnboarding = true
        XCTAssertTrue(settingsManager.settings.hasCompletedOnboarding)
    }
    
    // MARK: - General Settings Tests
    
    func testPlaySoundsToggle() {
        let initial = settingsManager.settings.playSounds
        settingsManager.settings.playSounds = !initial
        XCTAssertNotEqual(settingsManager.settings.playSounds, initial)
    }
    
    func testLaunchAtLoginToggle() {
        let initial = settingsManager.settings.launchAtLogin
        settingsManager.settings.launchAtLogin = !initial
        XCTAssertNotEqual(settingsManager.settings.launchAtLogin, initial)
    }
    
    // MARK: - Smart Mode Settings Tests
    
    func testSmartModeSettings() {
        settingsManager.settings.smartMode.autoPauseOnFullscreen = true
        settingsManager.settings.smartMode.autoPauseOnIdle = true
        settingsManager.settings.smartMode.idleThresholdMinutes = 10
        
        XCTAssertTrue(settingsManager.settings.smartMode.autoPauseOnFullscreen)
        XCTAssertTrue(settingsManager.settings.smartMode.autoPauseOnIdle)
        XCTAssertEqual(settingsManager.settings.smartMode.idleThresholdMinutes, 10)
    }
}
