//
//  LookAwaySetupViewTests.swift
//  GazeTests
//
//  Tests for LookAwaySetupView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class LookAwaySetupViewTests: XCTestCase {
    
    var testEnv: TestEnvironment!
    
    override func setUp() async throws {
        testEnv = TestEnvironment()
    }
    
    override func tearDown() async throws {
        testEnv = nil
    }
    
    func testLookAwaySetupInitialization() {
        // Use real SettingsManager for view initialization test since @Bindable requires concrete type
        let view = LookAwaySetupView(settingsManager: SettingsManager.shared)
        XCTAssertNotNil(view)
    }
    
    func testLookAwayTimerConfigurationChanges() {
        // Start with default
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 20)
        
        // Modify configuration
        testEnv.settingsManager.settings.lookAwayEnabled = true
        testEnv.settingsManager.settings.lookAwayIntervalMinutes = 25
        
        // Verify changes
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 25)
    }
    
    func testLookAwayTimerEnableDisable() {
        var config = testEnv.settingsManager.settings
        
        // Enable
        config.lookAwayEnabled = true
        config.lookAwayIntervalMinutes = 15
        testEnv.settingsManager.settings = config
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        
        // Disable
        config.lookAwayEnabled = false
        config.lookAwayIntervalMinutes = 10
        testEnv.settingsManager.settings = config
        XCTAssertFalse(testEnv.settingsManager.settings.lookAwayEnabled)
    }
    
    func testLookAwayIntervalValidation() {
        var config = testEnv.settingsManager.settings
        
        // Test various intervals (in minutes)
        let intervals = [5, 10, 20, 30, 60]
        for minutes in intervals {
            config.lookAwayEnabled = true
            config.lookAwayIntervalMinutes = minutes
            testEnv.settingsManager.settings = config
            
            let retrieved = testEnv.settingsManager.settings
            XCTAssertEqual(retrieved.lookAwayIntervalMinutes, minutes)
        }
    }
    
    func testLookAwayAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.lookAwayPage,
            "onboarding.page.lookAway"
        )
    }
}
