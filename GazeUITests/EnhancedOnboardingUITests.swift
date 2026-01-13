//
//  EnhancedOnboardingUITests.swift
//  GazeUITests
//
//  Created by Gaze Team on 1/13/26.
//

import XCTest

@MainActor
final class EnhancedOnboardingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--reset-onboarding")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testOnboardingCompleteFlowWithUserTimers() throws {
        // Navigate through the complete onboarding flow
        let continueButtons = app.buttons.matching(identifier: "Continue")
        let nextButtons = app.buttons.matching(identifier: "Next")
        
        var currentStep = 0
        let maxSteps = 15
        
        while currentStep < maxSteps {
            if continueButtons.firstMatch.exists && continueButtons.firstMatch.isHittable {
                continueButtons.firstMatch.tap()
                currentStep += 1
                sleep(1)
            } else if nextButtons.firstMatch.exists && nextButtons.firstMatch.isHittable {
                nextButtons.firstMatch.tap()
                currentStep += 1
                sleep(1)
            } else if app.buttons["Get Started"].exists {
                app.buttons["Get Started"].tap()
                break
            } else if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
                break
            } else {
                break
            }
        }
        
        // Verify onboarding completed successfully
        XCTAssertLessThan(currentStep, maxSteps, "Onboarding flow should complete")
        
        // Verify main application UI is visible (menubar should be active)
        XCTAssertTrue(app.menuBarItems.firstMatch.exists, "Menubar should be available after onboarding")
    }
    
    func testUserTimerCreationInOnboarding() throws {
        // Reset to fresh onboarding state
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        
        // Navigate to user timer setup section (assumes it's at the end)
        let continueButtons = app.buttons.matching(identifier: "Continue")
        let nextButtons = app.buttons.matching(identifier: "Next")
        
        // Skip through initial screens
        var currentStep = 0
        while currentStep < 8 && (continueButtons.firstMatch.exists || nextButtons.firstMatch.exists) {
            if continueButtons.firstMatch.exists && continueButtons.firstMatch.isHittable {
                continueButtons.firstMatch.tap()
                currentStep += 1
                sleep(1)
            } else if nextButtons.firstMatch.exists && nextButtons.firstMatch.isHittable {
                nextButtons.firstMatch.tap()
                currentStep += 1
                sleep(1)
            }
        }
        
        // Look for timer creation UI or related elements
        let timerSetupElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Timer' OR label CONTAINS 'Custom'")).firstMatch
        XCTAssertTrue(timerSetupElement.exists, "User timer setup section should be available during onboarding")
        
        // If we can create a timer in onboarding, test that flow
        if app.buttons["Add Timer"].exists {
            app.buttons["Add Timer"].tap()
            
            // Fill out timer details - this would be specific to the actual UI structure
            let titleField = app.textFields["Timer Title"]
            if titleField.exists {
                titleField.typeText("Test Timer")
            }
            
            let intervalField = app.textFields["Interval (minutes)"]
            if intervalField.exists {
                intervalField.typeText("10")
            }
            
            // Submit the timer
            app.buttons["Save"].tap()
        }
    }
    
    func testSettingsPersistenceAfterOnboarding() throws {
        // Reset to fresh onboarding state
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        
        // Complete onboarding flow
        let continueButtons = app.buttons.matching(identifier: "Continue")
        let nextButtons = app.buttons.matching(identifier: "Next")
        
        while continueButtons.firstMatch.exists || nextButtons.firstMatch.exists {
            if continueButtons.firstMatch.exists && continueButtons.firstMatch.isHittable {
                continueButtons.firstMatch.tap()
                sleep(1)
            } else if nextButtons.firstMatch.exists && nextButtons.firstMatch.isHittable {
                nextButtons.firstMatch.tap()
                sleep(1)
            }
        }
        
        // Get to the end and complete onboarding
        app.buttons["Get Started"].tap()
        
        // Verify that settings are properly initialized
        let menuBar = app.menuBarItems.firstMatch
        XCTAssertTrue(menuBar.exists, "Menubar should exist after onboarding")
        
        // Re-launch the app to verify settings persistence
        app.terminate()
        let newApp = XCUIApplication()
        newApp.launchArguments.append("--skip-onboarding")
        newApp.launch()
        
        XCTAssertTrue(newApp.menuBarItems.firstMatch.exists, "Application should maintain state after restart")
        newApp.terminate()
    }
    
    func testOnboardingNavigationEdgeCases() throws {
        // Test that navigation buttons work properly at each step
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
            
            // Verify we moved to the next screen
            let nextScreen = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Setup' OR label CONTAINS 'Configure'")).firstMatch
            XCTAssertTrue(nextScreen.exists, "Should navigate to next screen on Continue")
        }
        
        // Test back navigation
        let backButton = app.buttons["Back"]
        if backButton.waitForExistence(timeout: 1) {
            backButton.tap()
            
            // Should return to previous screen
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Welcome'")).firstMatch.exists)
        }
        
        // Test that we can go forward again
        let continueButton2 = app.buttons["Continue"]
        if continueButton2.waitForExistence(timeout: 1) {
            continueButton2.tap()
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Setup'")).firstMatch.exists)
        }
    }
}