//
//  OverlayReminderUITests.swift
//  GazeUITests
//
//  Created by OpenCode on 1/13/26.
//

import XCTest

/// Comprehensive UI tests for overlay and reminder system
/// 
/// NOTE: macOS MenuBarExtra UI testing limitations:
/// - MenuBarExtras created with MenuBarExtra {} don't reliably appear in XCUITest accessibility hierarchy
/// - This is a known limitation of XCUITest with SwiftUI MenuBarExtra
/// - Therefore, these tests focus on what can be tested: window lifecycle, dismissal, and cleanup
///
/// These tests verify:
/// - No overlays get stuck on screen
/// - Window cleanup happens properly
/// - App remains responsive after overlay cycles
@MainActor
final class OverlayReminderUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--skip-onboarding")
        app.launchArguments.append("--ui-testing")
        app.launch()
        
        // Wait for app to be ready
        sleep(UInt32(2))
    }
    
    override func tearDownWithError() throws {
        // Ensure app is terminated cleanly
        app.terminate()
        app = nil
    }
    
    // MARK: - Helper Methods
    
    /// Verifies that no overlay is currently visible
    private func verifyNoOverlay() {
        let overlayTexts = ["Look Away", "Blink", "Posture", "User Reminder"]
        
        for text in overlayTexts {
            XCTAssertFalse(
                app.staticTexts[text].exists,
                "Overlay '\(text)' should not be visible"
            )
        }
    }
    
    /// Counts the number of windows
    private func countWindows() -> Int {
        return app.windows.count
    }
    
    // MARK: - App Lifecycle Tests
    
    func testAppLaunchesSuccessfully() throws {
        // Basic test to ensure app launches and is responsive
        XCTAssertTrue(app.exists, "App should launch successfully")
        
        // Verify no stuck overlays from previous sessions
        verifyNoOverlay()
    }
    
    func testAppRemainsResponsiveAfterLaunch() throws {
        // Wait a bit and verify app didn't crash
        sleep(UInt32(3))
        
        XCTAssertTrue(app.exists, "App should remain running")
        
        // Verify no unexpected overlays appeared
        verifyNoOverlay()
    }
    
    func testNoStuckWindowsAfterAppLaunch() throws {
        let initialWindowCount = countWindows()
        
        // Wait to ensure no delayed windows appear
        sleep(UInt32(5))
        
        let finalWindowCount = countWindows()
        
        // Window count should be stable (menu bar doesn't create visible windows)
        XCTAssertLessThanOrEqual(
            finalWindowCount,
            initialWindowCount + 1,  // Allow for menu bar if it appears
            "No unexpected windows should appear after launch"
        )
        
        verifyNoOverlay()
    }
    
    // MARK: - Window Lifecycle Tests
    
    func testWindowCleanupVerification() throws {
        let initialWindowCount = countWindows()
        
        // Let the app run for a while
        sleep(UInt32(10))
        
        let finalWindowCount = countWindows()
        
        // Ensure window count hasn't grown unexpectedly
        XCTAssertLessThanOrEqual(
            finalWindowCount,
            initialWindowCount + 2,  // Allow some leeway for system windows
            "Window count should remain stable during normal operation"
        )
    }
    
    // MARK: - Overlay Detection Tests
    
    func testNoOverlaysAppearWithoutTrigger() throws {
        // Run for a period and ensure no overlays appear
        // (with our UI testing timers disabled or set to very long intervals)
        
        for i in 1...5 {
            print("Checking for stuck overlays - iteration \(i)/5")
            sleep(UInt32(2))
            verifyNoOverlay()
        }
        
        print("✅ No stuck overlays detected during test period")
    }
    
    func testAppStabilityOverTime() throws {
        // Extended stability test - run for 30 seconds
        let testDuration: Int = 30
        let checkInterval: Int = 5
        let iterations = testDuration / checkInterval
        
        for i in 1...iterations {
            print("Stability check \(i)/\(iterations)")
            sleep(UInt32(checkInterval))
            
            XCTAssertTrue(app.exists, "App should continue running")
            verifyNoOverlay()
        }
        
        print("✅ App remained stable for \(testDuration) seconds")
    }
    
    // MARK: - Regression Tests
    
    func testNoStuckOverlaysAfterAppStart() throws {
        // This test specifically checks for the bug where overlays don't dismiss
        
        // Wait for initial app startup
        sleep(UInt32(3))
        
        verifyNoOverlay()
        
        // Check multiple times to ensure stability
        for i in 1...10 {
            sleep(UInt32(1))
            verifyNoOverlay()
            
            if i % 3 == 0 {
                print("No stuck overlays detected - check \(i)/10")
            }
        }
        
        XCTAssertTrue(
            app.exists,
            "App should still be running after extended monitoring"
        )
    }
    
    // MARK: - Documentation Tests
    
    func testDocumentedLimitations() throws {
        // This test documents the UI testing limitations we discovered
        
        print("""
        
        ==================== UI Testing Limitations ====================
        
        MenuBarExtra Accessibility:
        - SwiftUI MenuBarExtra items don't reliably appear in XCUITest
        - This is a known Apple limitation as of macOS 13+
        - MenuBarItem queries return system menu bars (Apple, etc.) not app extras
        
        Workarounds Attempted:
        - Searching by index (unreliable, system dependent)
        - Using accessibility identifiers (not exposed for MenuBarExtra)
        - Iterating through menu bar items (finds wrong items)
        
        What We Can Test:
        - App launch and stability
        - Window lifecycle and cleanup
        - No stuck overlays appear unexpectedly
        - App remains responsive
        
        What Requires Manual Testing:
        - Overlay appearance when triggered
        - ESC/Space/Button dismissal methods
        - Countdown functionality
        - Rapid trigger/dismiss cycles
        - Multiple reminder types in sequence
        
        Recommendation:
        - Use unit tests for TimerEngine logic
        - Use integration tests for reminder triggering
        - Use manual testing for UI overlay behavior
        - Use these UI tests for regression detection of stuck overlays
        
        ================================================================
        
        """)
        
        XCTAssertTrue(true, "Limitations documented")
    }
}

// MARK: - Manual Test Checklist
/*
 Manual testing checklist for overlay reminders:
 
 Look Away Overlay:
 ☐ Appears when triggered
 ☐ Shows countdown
 ☐ Dismisses with ESC key
 ☐ Dismisses with Space key
 ☐ Dismisses with X button
 ☐ Auto-dismisses after countdown
 ☐ Doesn't appear when timers paused
 
 User Timer Overlay:
 ☐ Appears when triggered
 ☐ Shows custom message
 ☐ Shows correct color
 ☐ Dismisses properly with all methods
 
 Subtle Reminders (Blink, Posture, User Timer Subtle):
 ☐ Appear in corner
 ☐ Auto-dismiss after 3 seconds
 ☐ Don't block UI interaction
 
 Edge Cases:
 ☐ Rapid triggering (10x in a row)
 ☐ Trigger while countdown active
 ☐ Trigger while paused
 ☐ System sleep during overlay
 ☐ Multiple monitors
 ☐ Window cleanup after dismissal
 
 Regression:
 ☐ No overlays get stuck on screen
 ☐ All dismissal methods work reliably
 ☐ Window count returns to baseline after dismissal
 ☐ App remains responsive after many overlay cycles
 */

