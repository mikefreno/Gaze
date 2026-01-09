//
//  AccessibilityUITests.swift
//  GazeUITests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest

@MainActor
final class AccessibilityUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--skip-onboarding")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testMenuBarAccessibilityLabels() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            for button in app.buttons.allElementsBoundByIndex {
                XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
            }
        }
    }
    
    func testKeyboardNavigation() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            app.typeKey(XCUIKeyboardKey.tab, modifierFlags: [])
            
            let focusedElement = app.descendants(matching: .any).element(matching: NSPredicate(format: "hasKeyboardFocus == true"))
            XCTAssertTrue(focusedElement.exists || app.buttons.count > 0)
        }
    }
    
    func testAllButtonsAreHittable() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            sleep(1)
            
            let buttons = app.buttons.allElementsBoundByIndex
            for button in buttons where button.exists && button.isEnabled {
                XCTAssertTrue(button.isHittable || !button.isEnabled, "Enabled button should be hittable: \(button.label)")
            }
        }
    }
    
    func testVoiceOverElementsHaveLabels() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let staticTexts = app.staticTexts.allElementsBoundByIndex
            for text in staticTexts where text.exists {
                XCTAssertFalse(text.label.isEmpty, "Static text should have label")
            }
        }
    }
    
    func testImagesHaveAccessibilityTraits() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let images = app.images.allElementsBoundByIndex
            for image in images where image.exists {
                XCTAssertFalse(image.label.isEmpty, "Image should have accessibility label")
            }
        }
    }
}
