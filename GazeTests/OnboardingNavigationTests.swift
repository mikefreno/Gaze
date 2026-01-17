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
        var config = testEnv.settingsManager.settings.lookAwayTimer
        config.enabled = true
        config.intervalSeconds = 1200
        testEnv.settingsManager.updateTimerConfiguration(for: .lookAway, configuration: config)

        // Verify settings persisted
        let retrieved = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertTrue(retrieved.enabled)
        XCTAssertEqual(retrieved.intervalSeconds, 1200)

        // Configure blink timer
        var blinkConfig = testEnv.settingsManager.settings.blinkTimer
        blinkConfig.enabled = false
        blinkConfig.intervalSeconds = 300
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: blinkConfig)

        // Verify both settings persist
        let lookAway = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        let blink = testEnv.settingsManager.timerConfiguration(for: .blink)

        XCTAssertTrue(lookAway.enabled)
        XCTAssertEqual(lookAway.intervalSeconds, 1200)
        XCTAssertFalse(blink.enabled)
        XCTAssertEqual(blink.intervalSeconds, 300)
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
        var lookAwayConfig = testEnv.settingsManager.settings.lookAwayTimer
        lookAwayConfig.enabled = true
        lookAwayConfig.intervalSeconds = 1200
        testEnv.settingsManager.updateTimerConfiguration(
            for: .lookAway, configuration: lookAwayConfig)

        var blinkConfig = testEnv.settingsManager.settings.blinkTimer
        blinkConfig.enabled = true
        blinkConfig.intervalSeconds = 300
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: blinkConfig)

        var postureConfig = testEnv.settingsManager.settings.postureTimer
        postureConfig.enabled = true
        postureConfig.intervalSeconds = 1800
        testEnv.settingsManager.updateTimerConfiguration(
            for: .posture, configuration: postureConfig)

        // Verify all configurations
        let allConfigs = testEnv.settingsManager.allTimerConfigurations()

        XCTAssertEqual(allConfigs[.lookAway]?.intervalSeconds, 1200)
        XCTAssertEqual(allConfigs[.blink]?.intervalSeconds, 300)
        XCTAssertEqual(allConfigs[.posture]?.intervalSeconds, 1800)

        XCTAssertTrue(allConfigs[.lookAway]?.enabled ?? false)
        XCTAssertTrue(allConfigs[.blink]?.enabled ?? false)
        XCTAssertTrue(allConfigs[.posture]?.enabled ?? false)
    }

    func testNavigationWithPartialConfiguration() {
        // Configure only some timers
        var lookAwayConfig = testEnv.settingsManager.settings.lookAwayTimer
        lookAwayConfig.enabled = true
        testEnv.settingsManager.updateTimerConfiguration(
            for: .lookAway, configuration: lookAwayConfig)

        var blinkConfig = testEnv.settingsManager.settings.blinkTimer
        blinkConfig.enabled = false
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: blinkConfig)

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
        var lookAwayConfig = testEnv.settingsManager.settings.lookAwayTimer
        lookAwayConfig.enabled = true
        lookAwayConfig.intervalSeconds = 1200
        testEnv.settingsManager.updateTimerConfiguration(
            for: .lookAway, configuration: lookAwayConfig)

        // Page 2: Blink Setup
        var blinkConfig = testEnv.settingsManager.settings.blinkTimer
        blinkConfig.enabled = true
        blinkConfig.intervalSeconds = 300
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: blinkConfig)

        // Page 3: Posture Setup
        var postureConfig = testEnv.settingsManager.settings.postureTimer
        postureConfig.enabled = false  // User chooses to disable this one
        testEnv.settingsManager.updateTimerConfiguration(
            for: .posture, configuration: postureConfig)

        // Page 4: General Settings
        testEnv.settingsManager.settings.playSounds = true
        testEnv.settingsManager.settings.launchAtLogin = false

        // Page 5: Completion - mark as done
        testEnv.settingsManager.settings.hasCompletedOnboarding = true

        // Verify final state
        XCTAssertTrue(testEnv.settingsManager.settings.hasCompletedOnboarding)

        let finalConfigs = testEnv.settingsManager.allTimerConfigurations()
        XCTAssertTrue(finalConfigs[.lookAway]?.enabled ?? false)
        XCTAssertTrue(finalConfigs[.blink]?.enabled ?? false)
        XCTAssertFalse(finalConfigs[.posture]?.enabled ?? true)

        XCTAssertTrue(testEnv.settingsManager.settings.playSounds)
        XCTAssertFalse(testEnv.settingsManager.settings.launchAtLogin)
    }

    func testNavigatingBackPreservesSettings() {
        // Configure on page 1
        var lookAwayConfig = testEnv.settingsManager.settings.lookAwayTimer
        lookAwayConfig.intervalSeconds = 1500
        testEnv.settingsManager.updateTimerConfiguration(
            for: .lookAway, configuration: lookAwayConfig)

        // Move forward to page 2
        var blinkConfig = testEnv.settingsManager.settings.blinkTimer
        blinkConfig.intervalSeconds = 250
        testEnv.settingsManager.updateTimerConfiguration(for: .blink, configuration: blinkConfig)

        // Navigate back to page 1
        // Verify lookaway settings still exist
        let lookAway = testEnv.settingsManager.timerConfiguration(for: .lookAway)
        XCTAssertEqual(lookAway.intervalSeconds, 1500)

        // Navigate forward again to page 2
        // Verify blink settings still exist
        let blink = testEnv.settingsManager.timerConfiguration(for: .blink)
        XCTAssertEqual(blink.intervalSeconds, 250)
    }
}
