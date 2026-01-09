//
//  PerformanceUITests.swift
//  GazeUITests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest

@MainActor
final class PerformanceUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--skip-onboarding")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            app.terminate()
        }
    }
    
    func testMenuBarOpenPerformance() throws {
        app.launch()
        
        measure {
            let menuBar = app.menuBarItems.firstMatch
            if menuBar.waitForExistence(timeout: 5) {
                menuBar.click()
                _ = app.staticTexts["Gaze"].waitForExistence(timeout: 2)
            }
        }
    }
    
    func testSettingsWindowOpenPerformance() throws {
        app.launch()
        
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            menuBar.click()
            
            measure {
                let settingsButton = app.menuItems["Settings"]
                if settingsButton.waitForExistence(timeout: 2) {
                    settingsButton.click()
                    
                    let settingsWindow = app.windows["Settings"]
                    _ = settingsWindow.waitForExistence(timeout: 3)
                    
                    if settingsWindow.exists {
                        let closeButton = settingsWindow.buttons[XCUIIdentifierCloseWindow]
                        if closeButton.exists {
                            closeButton.click()
                        }
                    }
                }
                
                menuBar.click()
            }
        }
    }
    
    func testMemoryUsageDuringOperation() throws {
        app.launch()
        
        let menuBar = app.menuBarItems.firstMatch
        if menuBar.waitForExistence(timeout: 5) {
            measure(metrics: [XCTMemoryMetric()]) {
                for _ in 0..<5 {
                    menuBar.click()
                    sleep(1)
                    
                    menuBar.click()
                    sleep(1)
                }
            }
        }
    }
}
