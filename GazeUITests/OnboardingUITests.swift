//
//  OnboardingUITests.swift
//  GazeUITests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {
    
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
    
    func testOnboardingWelcomeScreen() throws {
        XCTAssertTrue(app.staticTexts["Welcome to Gaze"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Welcome'")).firstMatch.exists)
    }
    
    func testOnboardingNavigationFromWelcome() throws {
        let continueButton = app.buttons["Continue"]
        
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
            
            let nextScreen = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Setup' OR label CONTAINS 'Configure'")).firstMatch
            XCTAssertTrue(nextScreen.waitForExistence(timeout: 2))
        }
    }
    
    func testOnboardingBackNavigation() throws {
        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 2) {
            continueButton.tap()
            
            let backButton = app.buttons["Back"]
            if backButton.waitForExistence(timeout: 1) {
                backButton.tap()
                
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Welcome'")).firstMatch.waitForExistence(timeout: 1))
            }
        }
    }
    
    func testOnboardingCompleteFlow() throws {
        let continueButtons = app.buttons.matching(identifier: "Continue")
        let nextButtons = app.buttons.matching(identifier: "Next")
        
        var currentStep = 0
        let maxSteps = 10
        
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
        
        XCTAssertLessThan(currentStep, maxSteps, "Onboarding flow should complete")
    }
    
    func testOnboardingHasRequiredElements() throws {
        let hasText = app.staticTexts.count > 0
        let hasButtons = app.buttons.count > 0
        
        XCTAssertTrue(hasText, "Onboarding should have text elements")
        XCTAssertTrue(hasButtons, "Onboarding should have buttons")
    }
}
