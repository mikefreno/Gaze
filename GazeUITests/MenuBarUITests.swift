//
//  MenuBarUITests.swift
//  GazeUITests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest

@MainActor
final class MenuBarUITests: XCTestCase {
    
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
    
    func testMenuBarExtraExists() throws {
        let menuBar = app.menuBarItems.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 5))
    }
    
    func testMenuBarCanBeOpened() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let gazeTitle = app.staticTexts["Gaze"]
            XCTAssertTrue(gazeTitle.waitForExistence(timeout: 2) || app.staticTexts.count > 0)
        }
    }
    
    func testMenuBarHasTimerStatus() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let activeTimersText = app.staticTexts["Active Timers"]
            let hasTimerInfo = activeTimersText.exists || app.staticTexts.count > 3
            
            XCTAssertTrue(hasTimerInfo)
        }
    }
    
    func testMenuBarHasPauseResumeControl() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let pauseButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Pause' OR label CONTAINS 'Resume'")).firstMatch
            XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
        }
    }
    
    func testMenuBarHasSettingsButton() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let settingsButton = app.buttons["Settings"]
            let settingsMenuItem = app.menuItems["Settings"]
            
            XCTAssertTrue(settingsButton.exists || settingsMenuItem.exists)
        }
    }
    
    func testMenuBarHasQuitButton() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let quitButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Quit'")).firstMatch
            XCTAssertTrue(quitButton.waitForExistence(timeout: 2))
        }
    }
    
    func testPauseResumeToggle() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            let pauseButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Pause'")).firstMatch
            let resumeButton = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Resume'")).firstMatch
            
            if pauseButton.exists && pauseButton.isHittable {
                pauseButton.tap()
                XCTAssertTrue(resumeButton.waitForExistence(timeout: 2))
            } else if resumeButton.exists && resumeButton.isHittable {
                resumeButton.tap()
                XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
            }
        }
    }
}
