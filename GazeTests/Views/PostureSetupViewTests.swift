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
        let view = PostureSetupView(
            settingsManager: testEnv.settingsManager as! SettingsManager
        )
        XCTAssertNotNil(view)
    }
    
    func testPostureTimerConfigurationChanges() {
        let initial = testEnv.settingsManager.timerConfiguration(for: .posture)
        
        var modified = initial
        modified.enabled = true
        modified.intervalSeconds = 1800
        testEnv.settingsManager.updateTimerConfiguration(for: .posture, configuration: modified)
        
        let updated = testEnv.settingsManager.timerConfiguration(for: .posture)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.intervalSeconds, 1800)
    }
    
    func testPostureTimerEnableDisable() {
        var config = testEnv.settingsManager.timerConfiguration(for: .posture)
        
        config.enabled = true
        testEnv.settingsManager.updateTimerConfiguration(for: .posture, configuration: config)
        XCTAssertTrue(testEnv.settingsManager.timerConfiguration(for: .posture).enabled)
        
        config.enabled = false
        testEnv.settingsManager.updateTimerConfiguration(for: .posture, configuration: config)
        XCTAssertFalse(testEnv.settingsManager.timerConfiguration(for: .posture).enabled)
    }
    
    func testPostureIntervalValidation() {
        var config = testEnv.settingsManager.timerConfiguration(for: .posture)
        
        let intervals = [900, 1200, 1800, 2400, 3600]
        for interval in intervals {
            config.intervalSeconds = interval
            testEnv.settingsManager.updateTimerConfiguration(for: .posture, configuration: config)
            
            let retrieved = testEnv.settingsManager.timerConfiguration(for: .posture)
            XCTAssertEqual(retrieved.intervalSeconds, interval)
        }
    }
    
    func testPostureAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.posturePage,
            "onboarding.page.posture"
        )
    }
}
