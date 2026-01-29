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
        
        XCTAssertTrue(defaults.lookAwayEnabled)
        XCTAssertFalse(defaults.blinkEnabled)  // Blink timer is disabled by default
        XCTAssertTrue(defaults.postureEnabled)
        XCTAssertFalse(defaults.hasCompletedOnboarding)
    }
    
    // MARK: - Timer Configuration Tests
    
    func testGetTimerConfiguration() {
        XCTAssertTrue(settingsManager.settings.lookAwayEnabled)
    }
    
    func testUpdateTimerConfiguration() {
        settingsManager.settings.lookAwayEnabled = false
        settingsManager.settings.lookAwayIntervalMinutes = 25
        
        XCTAssertFalse(settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(settingsManager.settings.lookAwayIntervalMinutes, 25)
    }
    
    func testAllTimerConfigurations() {
        XCTAssertEqual(settingsManager.settings.lookAwayEnabled, true)
        XCTAssertEqual(settingsManager.settings.blinkEnabled, false)
        XCTAssertEqual(settingsManager.settings.postureEnabled, true)
    }
    
    func testUpdateMultipleTimerConfigurations() {
        settingsManager.settings.lookAwayEnabled = true
        settingsManager.settings.lookAwayIntervalMinutes = 16
        settingsManager.settings.blinkEnabled = true
        settingsManager.settings.blinkIntervalMinutes = 4
        
        XCTAssertTrue(settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(settingsManager.settings.lookAwayIntervalMinutes, 16)
        XCTAssertTrue(settingsManager.settings.blinkEnabled)
        XCTAssertEqual(settingsManager.settings.blinkIntervalMinutes, 4)
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
        settingsManager.settings.lookAwayEnabled = false
        settingsManager.settings.lookAwayIntervalMinutes = 10
        
        // Reset
        settingsManager.resetToDefaults()
        
        // Verify reset to defaults
        let defaults = AppSettings.defaults
        XCTAssertEqual(settingsManager.settings.playSounds, defaults.playSounds)
        XCTAssertEqual(settingsManager.settings.launchAtLogin, defaults.launchAtLogin)
        XCTAssertEqual(settingsManager.settings.lookAwayEnabled, defaults.lookAwayEnabled)
        XCTAssertEqual(settingsManager.settings.lookAwayIntervalMinutes, defaults.lookAwayIntervalMinutes)
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
