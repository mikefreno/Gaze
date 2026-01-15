//
//  GeneralSetupViewTests.swift
//  GazeTests
//
//  Tests for GeneralSetupView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class GeneralSetupViewTests: XCTestCase {
    
    var testEnv: TestEnvironment!
    
    override func setUp() async throws {
        testEnv = TestEnvironment()
    }
    
    override func tearDown() async throws {
        testEnv = nil
    }
    
    func testGeneralSetupInitialization() {
        let view = GeneralSetupView(
            settingsManager: testEnv.settingsManager as! SettingsManager,
            isOnboarding: true
        )
        XCTAssertNotNil(view)
    }
    
    func testPlaySoundsToggle() {
        // Initial state
        let initial = testEnv.settingsManager.settings.playSounds
        
        // Toggle on
        testEnv.settingsManager.settings.playSounds = true
        XCTAssertTrue(testEnv.settingsManager.settings.playSounds)
        
        // Toggle off
        testEnv.settingsManager.settings.playSounds = false
        XCTAssertFalse(testEnv.settingsManager.settings.playSounds)
    }
    
    func testLaunchAtLoginToggle() {
        // Toggle on
        testEnv.settingsManager.settings.launchAtLogin = true
        XCTAssertTrue(testEnv.settingsManager.settings.launchAtLogin)
        
        // Toggle off
        testEnv.settingsManager.settings.launchAtLogin = false
        XCTAssertFalse(testEnv.settingsManager.settings.launchAtLogin)
    }
    
    func testMultipleSettingsConfiguration() {
        testEnv.settingsManager.settings.playSounds = true
        testEnv.settingsManager.settings.launchAtLogin = true
        
        XCTAssertTrue(testEnv.settingsManager.settings.playSounds)
        XCTAssertTrue(testEnv.settingsManager.settings.launchAtLogin)
        
        testEnv.settingsManager.settings.playSounds = false
        XCTAssertFalse(testEnv.settingsManager.settings.playSounds)
        XCTAssertTrue(testEnv.settingsManager.settings.launchAtLogin)
    }
    
    func testGeneralAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.generalPage,
            "onboarding.page.general"
        )
    }
}
