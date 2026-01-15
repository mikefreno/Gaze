//
//  MockWindowManager.swift
//  GazeTests
//
//  A mock implementation of WindowManaging for isolated unit testing.
//

import SwiftUI
@testable import Gaze

/// A mock implementation of WindowManaging that doesn't create real windows.
/// This allows tests to run in complete isolation without affecting the UI.
@MainActor
final class MockWindowManager: WindowManaging {
    
    // MARK: - State tracking
    
    var isOverlayReminderVisible: Bool = false
    var isSubtleReminderVisible: Bool = false
    
    // MARK: - Call tracking for verification
    
    var showReminderWindowCalls: [(windowType: ReminderWindowType, viewType: String)] = []
    var dismissOverlayReminderCallCount = 0
    var dismissSubtleReminderCallCount = 0
    var dismissAllRemindersCallCount = 0
    var showSettingsCalls: [Int] = []
    var showOnboardingCallCount = 0
    
    /// The last window type shown
    var lastShownWindowType: ReminderWindowType?
    
    // MARK: - WindowManaging conformance
    
    func showReminderWindow<Content: View>(_ content: Content, windowType: ReminderWindowType) {
        let viewType = String(describing: type(of: content))
        showReminderWindowCalls.append((windowType: windowType, viewType: viewType))
        lastShownWindowType = windowType
        
        switch windowType {
        case .overlay:
            isOverlayReminderVisible = true
        case .subtle:
            isSubtleReminderVisible = true
        }
    }
    
    func dismissOverlayReminder() {
        dismissOverlayReminderCallCount += 1
        isOverlayReminderVisible = false
    }
    
    func dismissSubtleReminder() {
        dismissSubtleReminderCallCount += 1
        isSubtleReminderVisible = false
    }
    
    func dismissAllReminders() {
        dismissAllRemindersCallCount += 1
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
    }
    
    func showSettings(settingsManager: any SettingsProviding, initialTab: Int) {
        showSettingsCalls.append(initialTab)
    }
    
    func showOnboarding(settingsManager: any SettingsProviding) {
        showOnboardingCallCount += 1
    }
    
    // MARK: - Test helpers
    
    /// Resets all call tracking counters
    func resetCallTracking() {
        showReminderWindowCalls = []
        dismissOverlayReminderCallCount = 0
        dismissSubtleReminderCallCount = 0
        dismissAllRemindersCallCount = 0
        showSettingsCalls = []
        showOnboardingCallCount = 0
        lastShownWindowType = nil
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
    }
    
    /// Returns the number of overlay windows shown
    var overlayWindowsShownCount: Int {
        showReminderWindowCalls.filter { $0.windowType == .overlay }.count
    }
    
    /// Returns the number of subtle windows shown
    var subtleWindowsShownCount: Int {
        showReminderWindowCalls.filter { $0.windowType == .subtle }.count
    }
    
    /// Checks if a specific view type was shown
    func wasViewShown(containing typeName: String) -> Bool {
        showReminderWindowCalls.contains { $0.viewType.contains(typeName) }
    }
}
