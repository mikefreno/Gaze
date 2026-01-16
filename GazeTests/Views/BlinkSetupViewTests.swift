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
        let initial = testEnv.settingsManager.timerConfiguration(for: .blink)
        
        var modified = initial
        modified.enabled = true
        modified.intervalSeconds = 300
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: modified)
        
        let updated = testEnv.settingsManager.timerConfiguration(for: .blink)
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.intervalSeconds, 300)
    }
    
    func testBlinkTimerEnableDisable() {
        var config = testEnv.settingsManager.timerConfiguration(for: .blink)
        
        config.enabled = true
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: config)
        XCTAssertTrue(testEnv.settingsManager.timerConfiguration(for: .blink).enabled)
        
        config.enabled = false
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: config)
        XCTAssertFalse(testEnv.settingsManager.timerConfiguration(for: .blink).enabled)
    }
    
    func testBlinkIntervalValidation() {
        var config = testEnv.settingsManager.timerConfiguration(for: .blink)
        
        let intervals = [180, 240, 300, 360, 600]
        for interval in intervals {
            config.intervalSeconds = interval
            testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: config)
            
            let retrieved = testEnv.settingsManager.timerConfiguration(for: .blink)
            XCTAssertEqual(retrieved.intervalSeconds, interval)
        }
    }
    
    func testBlinkAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.blinkPage,
            "onboarding.page.blink"
        )
    }
}
