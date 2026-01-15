//
//  WindowManagerTests.swift
//  GazeTests
//
//  Unit tests for WindowManager service.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class WindowManagerTests: XCTestCase {
    
    var windowManager: WindowManager!
    
    override func setUp() async throws {
        windowManager = WindowManager.shared
    }
    
    override func tearDown() async throws {
        windowManager.dismissAllReminders()
        windowManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testWindowManagerInitialization() {
        XCTAssertNotNil(windowManager)
    }
    
    func testInitialState() {
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
    }
    
    // MARK: - Window Visibility Tests
    
    func testOverlayReminderVisibility() {
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        
        let view = Text("Test Overlay")
        windowManager.showReminderWindow(view, windowType: .overlay)
        
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        
        windowManager.dismissOverlayReminder()
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
    }
    
    func testSubtleReminderVisibility() {
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
        
        let view = Text("Test Subtle")
        windowManager.showReminderWindow(view, windowType: .subtle)
        
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
        
        windowManager.dismissSubtleReminder()
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
    }
    
    // MARK: - Multiple Window Tests
    
    func testShowBothWindowTypes() {
        let overlayView = Text("Overlay")
        let subtleView = Text("Subtle")
        
        windowManager.showReminderWindow(overlayView, windowType: .overlay)
        windowManager.showReminderWindow(subtleView, windowType: .subtle)
        
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
    }
    
    func testDismissAllReminders() {
        let overlayView = Text("Overlay")
        let subtleView = Text("Subtle")
        
        windowManager.showReminderWindow(overlayView, windowType: .overlay)
        windowManager.showReminderWindow(subtleView, windowType: .subtle)
        
        windowManager.dismissAllReminders()
        
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
    }
    
    // MARK: - Window Replacement Tests
    
    func testReplaceOverlayWindow() {
        let firstView = Text("First Overlay")
        let secondView = Text("Second Overlay")
        
        windowManager.showReminderWindow(firstView, windowType: .overlay)
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        
        // Showing a new overlay should replace the old one
        windowManager.showReminderWindow(secondView, windowType: .overlay)
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
    }
    
    func testReplaceSubtleWindow() {
        let firstView = Text("First Subtle")
        let secondView = Text("Second Subtle")
        
        windowManager.showReminderWindow(firstView, windowType: .subtle)
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
        
        windowManager.showReminderWindow(secondView, windowType: .subtle)
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
    }
    
    // MARK: - Integration with Settings Tests
    
    func testShowSettingsWithSettingsManager() {
        let settingsManager = SettingsManager.shared
        
        // Should not crash
        windowManager.showSettings(settingsManager: settingsManager, initialTab: 0)
    }
    
    func testShowOnboardingWithSettingsManager() {
        let settingsManager = SettingsManager.shared
        
        // Should not crash
        windowManager.showOnboarding(settingsManager: settingsManager)
    }
}
