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
        let initial = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        
        // Modify configuration
        var modified = initial
        modified.enabled = true
        modified.intervalSeconds = 1500
        testEnv.settingsManager.updateTimerConfiguration(for: .lookAway, configuration: modified)
        
        // Verify changes
        let updated = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.intervalSeconds, 1500)
    }
    
    func testLookAwayTimerEnableDisable() {
        var config = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        
        // Enable
        config.enabled = true
        testEnv.settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        XCTAssertTrue(testEnv.settingsManager.timerConfiguration(for: .lookAway).enabled)
        
        // Disable
        config.enabled = false
        testEnv.settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
        XCTAssertFalse(testEnv.settingsManager.timerConfiguration(for: .lookAway).enabled)
    }
    
    func testLookAwayIntervalValidation() {
        var config = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        
        // Test various intervals
        let intervals = [300, 600, 1200, 1800, 3600]
        for interval in intervals {
            config.intervalSeconds = interval
            testEnv.settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)
            
            let retrieved = testEnv.settingsManager.timerConfiguration(for: .lookAway)
            XCTAssertEqual(retrieved.intervalSeconds, interval)
        }
    }
    
    func testLookAwayAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.lookAwayPage,
            "onboarding.page.lookAway"
        )
    }
}
