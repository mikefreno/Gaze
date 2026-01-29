//
//  BlinkSetupViewTests.swift
//  GazeTests
//
//  Tests for BlinkSetupView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class BlinkSetupViewTests: XCTestCase {
    
    var testEnv: TestEnvironment!
    
    override func setUp() async throws {
        testEnv = TestEnvironment()
    }
    
    override func tearDown() async throws {
        testEnv = nil
    }
    
    func testBlinkSetupInitialization() {
        // Use real SettingsManager for view initialization test since @Bindable requires concrete type
        let view = BlinkSetupView(settingsManager: SettingsManager.shared)
        XCTAssertNotNil(view)
    }
    
    func testBlinkTimerConfigurationChanges() {
        XCTAssertFalse(testEnv.settingsManager.settings.blinkEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.blinkIntervalMinutes, 7)
        
        testEnv.settingsManager.settings.blinkEnabled = true
        testEnv.settingsManager.settings.blinkIntervalMinutes = 5
        
        XCTAssertTrue(testEnv.settingsManager.settings.blinkEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.blinkIntervalMinutes, 5)
    }
    
    func testBlinkTimerEnableDisable() {
        var config = testEnv.settingsManager.settings
        
        config.blinkEnabled = true
        config.blinkIntervalMinutes = 4
        testEnv.settingsManager.settings = config
        XCTAssertTrue(testEnv.settingsManager.settings.blinkEnabled)
        
        config.blinkEnabled = false
        config.blinkIntervalMinutes = 3
        testEnv.settingsManager.settings = config
        XCTAssertFalse(testEnv.settingsManager.settings.blinkEnabled)
    }
    
    func testBlinkIntervalValidation() {
        var config = testEnv.settingsManager.settings
        
        let intervals = [3, 4, 5, 6, 10]
        for minutes in intervals {
            config.blinkEnabled = true
            config.blinkIntervalMinutes = minutes
            testEnv.settingsManager.settings = config
            
            let retrieved = testEnv.settingsManager.settings
            XCTAssertEqual(retrieved.blinkIntervalMinutes, minutes)
        }
    }
    
    func testBlinkAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.blinkPage,
            "onboarding.page.blink"
        )
    }
}
