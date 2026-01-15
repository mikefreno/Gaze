//
//  AppDelegateTestabilityTests.swift
//  GazeTests
//
//  Tests demonstrating AppDelegate testability with dependency injection.
//

import XCTest
@testable import Gaze

@MainActor
final class AppDelegateTestabilityTests: XCTestCase {
    
    var testEnv: TestEnvironment!
    
    override func setUp() async throws {
        testEnv = TestEnvironment(settings: .onboardingCompleted)
    }
    
    override func tearDown() async throws {
        testEnv = nil
    }
    
    func testAppDelegateCreationWithMocks() {
        let appDelegate = testEnv.createAppDelegate()
        
        XCTAssertNotNil(appDelegate)
    }
    
    func testWindowManagerReceivesReminderEvents() async throws {
        let appDelegate = testEnv.createAppDelegate()
        
        // Simulate app launch
        let notification = Notification(name: NSApplication.didFinishLaunchingNotification)
        appDelegate.applicationDidFinishLaunching(notification)
        
        // Give time for setup
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Trigger a reminder through timer engine
        if let timerEngine = appDelegate.timerEngine {
            let timerId = TimerIdentifier.builtIn(.blink)
            timerEngine.triggerReminder(for: timerId)
            
            // Give time for reminder to propagate
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Verify window manager received the show command
            XCTAssertTrue(testEnv.windowManager.didPerformOperation(.showSubtleReminder))
        } else {
            XCTFail("TimerEngine not initialized")
        }
    }
    
    func testSettingsChangesPropagate() async throws {
        let appDelegate = testEnv.createAppDelegate()
        
        // Change a setting
        testEnv.settingsManager.settings.lookAwayTimer.enabled = false
        
        // Give time for observation
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Verify the change propagated
        XCTAssertFalse(testEnv.settingsManager.settings.lookAwayTimer.enabled)
    }
    
    func testOpenSettingsUsesWindowManager() {
        let appDelegate = testEnv.createAppDelegate()
        
        appDelegate.openSettings(tab: 2)
        
        // Give time for async dispatch
        let expectation = XCTestExpectation(description: "Settings opened")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.testEnv.windowManager.didPerformOperation(.showSettings(initialTab: 2)))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOpenOnboardingUsesWindowManager() {
        let appDelegate = testEnv.createAppDelegate()
        
        appDelegate.openOnboarding()
        
        // Give time for async dispatch
        let expectation = XCTestExpectation(description: "Onboarding opened")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertTrue(self.testEnv.windowManager.didPerformOperation(.showOnboarding))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
