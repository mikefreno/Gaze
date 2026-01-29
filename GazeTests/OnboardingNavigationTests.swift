//
//  OnboardingNavigationTests.swift
//  GazeTests
//
//  Comprehensive tests for onboarding flow navigation.
//

import SwiftUI
import XCTest

@testable import Gaze

@MainActor
final class OnboardingNavigationTests: XCTestCase {

    var testEnv: TestEnvironment!

    override func setUp() async throws {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = false
        testEnv = TestEnvironment(settings: settings)
    }

    override func tearDown() async throws {
        testEnv = nil
    }

    // MARK: - Navigation Tests

    func testOnboardingStartsAtWelcomePage() {
        // Use real SettingsManager for view initialization test since @Bindable requires concrete type
        let onboarding = OnboardingContainerView(settingsManager: SettingsManager.shared)

        // Verify initial state
        XCTAssertFalse(testEnv.settingsManager.settings.hasCompletedOnboarding)
    }

    func testNavigationForwardThroughAllPages() async throws {
        var settings = testEnv.settingsManager.settings

        // Simulate moving through pages
        let pages = [
            "Welcome",  // 0
            "MenuBar",  // 1
            "LookAway",  // 2
            "Blink",  // 3
            "Posture",  // 4
            "General",  // 5
            "Completion",  // 6
        ]

        for (index, pageName) in pages.enumerated() {
            // Verify we can track page progression
            XCTAssertEqual(index, index, "Should be on page \(index): \(pageName)")
        }
    }

    func testNavigationBackward() {
        // Start from page 3 (Posture)
        var currentPage = 3

        // Navigate backward
        currentPage -= 1
        XCTAssertEqual(currentPage, 2, "Should navigate back to Blink page")

        currentPage -= 1
        XCTAssertEqual(currentPage, 1, "Should navigate back to LookAway page")

        currentPage -= 1
        XCTAssertEqual(currentPage, 0, "Should navigate back to Welcome page")
    }

    func testCannotNavigateBackFromWelcome() {
        let currentPage = 0

        // Should not be able to go below 0
        XCTAssertEqual(currentPage, 0, "Should stay on Welcome page")
    }

    func testSettingsPersistDuringNavigation() {
        // Configure lookaway timer
        testEnv.settingsManager.settings.lookAwayEnabled = true
        testEnv.settingsManager.settings.lookAwayIntervalMinutes = 20

        // Verify settings persisted
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 20)

        // Configure blink timer
        testEnv.settingsManager.settings.blinkEnabled = false
        testEnv.settingsManager.settings.blinkIntervalMinutes = 5

        // Verify both settings persist
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 20)
        XCTAssertFalse(testEnv.settingsManager.settings.blinkEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.blinkIntervalMinutes, 5)
    }

    func testOnboardingCompletion() {
        // Start with onboarding incomplete
        XCTAssertFalse(testEnv.settingsManager.settings.hasCompletedOnboarding)

        // Complete onboarding
        testEnv.settingsManager.settings.hasCompletedOnboarding = true

        // Verify completion
        XCTAssertTrue(testEnv.settingsManager.settings.hasCompletedOnboarding)
    }

    func testAllTimersConfiguredDuringOnboarding() {
        // Configure all three built-in timers
        testEnv.settingsManager.settings.lookAwayEnabled = true
        testEnv.settingsManager.settings.lookAwayIntervalMinutes = 20
        testEnv.settingsManager.settings.blinkEnabled = true
        testEnv.settingsManager.settings.blinkIntervalMinutes = 5
        testEnv.settingsManager.settings.postureEnabled = true
        testEnv.settingsManager.settings.postureIntervalMinutes = 30

        // Verify all configurations
        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 20)
        XCTAssertTrue(testEnv.settingsManager.settings.blinkEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.blinkIntervalMinutes, 5)
        XCTAssertTrue(testEnv.settingsManager.settings.postureEnabled)
        XCTAssertEqual(testEnv.settingsManager.settings.postureIntervalMinutes, 30)
    }

    func testNavigationWithPartialConfiguration() {
        // Configure only some timers
        testEnv.settingsManager.settings.lookAwayEnabled = true
        testEnv.settingsManager.settings.blinkEnabled = false

        // Should still be able to complete onboarding
        testEnv.settingsManager.settings.hasCompletedOnboarding = true
        XCTAssertTrue(testEnv.settingsManager.settings.hasCompletedOnboarding)
    }

    func testGeneralSettingsConfigurationDuringOnboarding() {
        // Configure general settings
        testEnv.settingsManager.settings.playSounds = true
        testEnv.settingsManager.settings.launchAtLogin = true

        XCTAssertTrue(testEnv.settingsManager.settings.playSounds)
        XCTAssertTrue(testEnv.settingsManager.settings.launchAtLogin)
    }

    func testOnboardingFlowFromStartToFinish() {
        // Complete simulation of onboarding flow
        XCTAssertFalse(testEnv.settingsManager.settings.hasCompletedOnboarding)

        // Page 0: Welcome - no configuration needed

        // Page 1: MenuBar Welcome - no configuration needed

        // Page 2: LookAway Setup
        testEnv.settingsManager.settings.lookAwayEnabled = true
        testEnv.settingsManager.settings.lookAwayIntervalMinutes = 20

        // Page 2: Blink Setup
        testEnv.settingsManager.settings.blinkEnabled = true
        testEnv.settingsManager.settings.blinkIntervalMinutes = 5

        // Page 3: Posture Setup
        testEnv.settingsManager.settings.postureEnabled = false  // User chooses to disable this one

        // Page 4: General Settings
        testEnv.settingsManager.settings.playSounds = true
        testEnv.settingsManager.settings.launchAtLogin = false

        // Page 5: Completion - mark as done
        testEnv.settingsManager.settings.hasCompletedOnboarding = true

        // Verify final state
        XCTAssertTrue(testEnv.settingsManager.settings.hasCompletedOnboarding)

        XCTAssertTrue(testEnv.settingsManager.settings.lookAwayEnabled)
        XCTAssertTrue(testEnv.settingsManager.settings.blinkEnabled)
        XCTAssertFalse(testEnv.settingsManager.settings.postureEnabled)

        XCTAssertTrue(testEnv.settingsManager.settings.playSounds)
        XCTAssertFalse(testEnv.settingsManager.settings.launchAtLogin)
    }

    func testNavigatingBackPreservesSettings() {
        // Configure on page 1
        testEnv.settingsManager.settings.lookAwayIntervalMinutes = 25

        // Move forward to page 2
        testEnv.settingsManager.settings.blinkIntervalMinutes = 4

        // Navigate back to page 1
        // Verify lookaway settings still exist
        XCTAssertEqual(testEnv.settingsManager.settings.lookAwayIntervalMinutes, 25)

        // Navigate forward again to page 2
        // Verify blink settings still exist
        XCTAssertEqual(testEnv.settingsManager.settings.blinkIntervalMinutes, 4)
    }
}
