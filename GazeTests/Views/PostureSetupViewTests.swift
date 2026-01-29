//
//  PostureSetupViewTests.swift
//  GazeTests
//
//  Tests for PostureSetupView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class PostureSetupViewTests: XCTestCase {
    
    var testEnv: TestEnvironment!
    
    override func setUp() async throws {
        testEnv = TestEnvironment()
    }
    
    override func tearDown() async throws {
        testEnv = nil
    }
    
    func testPostureSetupInitialization() {
        // Use real SettingsManager for view initialization test since @Bindable requires concrete type
        let view = PostureSetupView(settingsManager: SettingsManager.shared)
        XCTAssertNotNil(view)
    }
    
    func testPostureTimerConfigurationChanges() {
        // Start with default
        XCTAssertTrue(testEnv.settingsManager.settings.postureEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.postureIntervalMinutes, 30)
        
        // Modify configuration
        testEnv.settingsManager.settings.postureEnabled = true
        testEnv.settingsManager.settings.postureIntervalMinutes = 45
        
        // Verify changes
        XCTAssertTrue(testEnv.settingsManager.settings.postureEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.postureIntervalMinutes, 45)
    }
    
    func testPostureTimerEnableDisable() {
        var config = testEnv.settingsManager.settings
        
        // Enable
        config.postureEnabled = true
        config.postureIntervalMinutes = 25
        testEnv.settingsManager.settings = config
        XCTAssertTrue(testEnv.settingsManager.settings.postureEnabled)
        
        // Disable
        config.postureEnabled = false
        config.postureIntervalMinutes = 20
        testEnv.settingsManager.settings = config
        XCTAssertFalse(testEnv.settingsManager.settings.postureEnabled)
    }
    
    func testPostureIntervalValidation() {
        var config = testEnv.settingsManager.settings
        
        // Test various intervals (in minutes)
        let intervals = [15, 20, 30, 45, 60]
        for minutes in intervals {
            config.postureEnabled = true
            config.postureIntervalMinutes = minutes
            testEnv.settingsManager.settings = config
            
            let retrieved = testEnv.settingsManager.settings
            XCTAssertEqual(retrieved.postureIntervalMinutes, minutes)
        }
    }
    
    func testPostureAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.posturePage,
            "onboarding.page.posture"
        )
    }
}
