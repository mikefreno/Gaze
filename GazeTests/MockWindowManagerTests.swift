//
//  MockWindowManagerTests.swift
//  GazeTests
//
//  Tests for MockWindowManager functionality.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class MockWindowManagerTests: XCTestCase {
    
    var windowManager: MockWindowManager!
    
    override func setUp() async throws {
        windowManager = MockWindowManager()
    }
    
    override func tearDown() async throws {
        windowManager = nil
    }
    
    func testShowOverlayReminder() {
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        
        let view = Text("Test Overlay")
        windowManager.showReminderWindow(view, windowType: .overlay)
        
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        XCTAssertTrue(windowManager.didPerformOperation(.showOverlayReminder))
    }
    
    func testShowSubtleReminder() {
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
        
        let view = Text("Test Subtle")
        windowManager.showReminderWindow(view, windowType: .subtle)
        
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
        XCTAssertTrue(windowManager.didPerformOperation(.showSubtleReminder))
    }
    
    func testDismissOverlayReminder() {
        let view = Text("Test")
        windowManager.showReminderWindow(view, windowType: .overlay)
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        
        windowManager.dismissOverlayReminder()
        
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        XCTAssertTrue(windowManager.didPerformOperation(.dismissOverlayReminder))
    }
    
    func testDismissAllReminders() {
        let view = Text("Test")
        windowManager.showReminderWindow(view, windowType: .overlay)
        windowManager.showReminderWindow(view, windowType: .subtle)
        
        XCTAssertTrue(windowManager.isOverlayReminderVisible)
        XCTAssertTrue(windowManager.isSubtleReminderVisible)
        
        windowManager.dismissAllReminders()
        
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        XCTAssertFalse(windowManager.isSubtleReminderVisible)
    }
    
    func testOperationTracking() {
        let view = Text("Test")
        
        windowManager.showReminderWindow(view, windowType: .overlay)
        windowManager.showReminderWindow(view, windowType: .overlay)
        windowManager.dismissOverlayReminder()
        
        XCTAssertEqual(windowManager.operationCount(.showOverlayReminder), 2)
        XCTAssertEqual(windowManager.operationCount(.dismissOverlayReminder), 1)
    }
    
    func testCallbacks() {
        var overlayShown = false
        windowManager.onShowOverlayReminder = {
            overlayShown = true
        }
        
        let view = Text("Test")
        windowManager.showReminderWindow(view, windowType: .overlay)
        
        XCTAssertTrue(overlayShown)
    }
    
    func testReset() {
        let view = Text("Test")
        windowManager.showReminderWindow(view, windowType: .overlay)
        windowManager.onShowOverlayReminder = { }
        
        windowManager.reset()
        
        XCTAssertFalse(windowManager.isOverlayReminderVisible)
        XCTAssertEqual(windowManager.operations.count, 0)
        XCTAssertNil(windowManager.onShowOverlayReminder)
    }
}
