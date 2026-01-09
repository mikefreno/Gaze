//
//  SettingsUITests.swift
//  GazeUITests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    
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
    
    func testOpenSettingsWindow() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.exists {
            menuBar.click()
            
            let settingsButton = app.menuItems["Settings"]
            if settingsButton.waitForExistence(timeout: 2) {
                settingsButton.click()
                
                let settingsWindow = app.windows["Settings"]
                XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))
            }
        }
    }
    
    func testSettingsWindowHasTimerControls() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.exists {
            menuBar.click()
            
            let settingsButton = app.menuItems["Settings"]
            if settingsButton.waitForExistence(timeout: 2) {
                settingsButton.click()
                
                sleep(1)
                
                let hasSliders = app.sliders.count > 0
                let hasTextFields = app.textFields.count > 0
                let hasSwitches = app.switches.count > 0
                
                let hasControls = hasSliders || hasTextFields || hasSwitches
                XCTAssertTrue(hasControls, "Settings should have timer controls")
            }
        }
    }
    
    func testSettingsWindowCanBeClosed() throws {
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.exists {
            menuBar.click()
            
            let settingsButton = app.menuItems["Settings"]
            if settingsButton.waitForExistence(timeout: 2) {
                settingsButton.click()
                
                let settingsWindow = app.windows["Settings"]
                if settingsWindow.waitForExistence(timeout: 3) {
                    let closeButton = settingsWindow.buttons[XCUIIdentifierCloseWindow]
                    if closeButton.exists {
                        closeButton.click()
                        
                        XCTAssertFalse(settingsWindow.exists)
                    }
                }
            }
        }
    }
}
