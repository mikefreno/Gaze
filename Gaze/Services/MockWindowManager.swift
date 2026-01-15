//
//  MockWindowManager.swift
//  Gaze
//
//  Mock implementation of WindowManaging for testing purposes.
//

import SwiftUI

/// Mock window manager that tracks window operations without creating actual windows.
/// Useful for unit testing UI flows and state management.
@MainActor
final class MockWindowManager: WindowManaging {
    
    // MARK: - State Tracking
    
    private(set) var isOverlayReminderVisible = false
    private(set) var isSubtleReminderVisible = false
    
    // MARK: - Operation History
    
    struct WindowOperation {
        let timestamp: Date
        let operation: Operation
        
        enum Operation {
            case showOverlayReminder
            case showSubtleReminder
            case dismissOverlayReminder
            case dismissSubtleReminder
            case dismissAllReminders
            case showSettings(initialTab: Int)
            case showOnboarding
        }
    }
    
    private(set) var operations: [WindowOperation] = []
    
    // MARK: - Callbacks for Testing
    
    var onShowOverlayReminder: (() -> Void)?
    var onShowSubtleReminder: (() -> Void)?
    var onDismissOverlayReminder: (() -> Void)?
    var onDismissSubtleReminder: (() -> Void)?
    var onShowSettings: ((Int) -> Void)?
    var onShowOnboarding: (() -> Void)?
    
    // MARK: - WindowManaging Implementation
    
    func showReminderWindow<Content: View>(_ content: Content, windowType: ReminderWindowType) {
        let operation: WindowOperation.Operation
        
        switch windowType {
        case .overlay:
            isOverlayReminderVisible = true
            operation = .showOverlayReminder
            onShowOverlayReminder?()
        case .subtle:
            isSubtleReminderVisible = true
            operation = .showSubtleReminder
            onShowSubtleReminder?()
        }
        
        operations.append(WindowOperation(timestamp: Date(), operation: operation))
    }
    
    func dismissOverlayReminder() {
        isOverlayReminderVisible = false
        operations.append(WindowOperation(timestamp: Date(), operation: .dismissOverlayReminder))
        onDismissOverlayReminder?()
    }
    
    func dismissSubtleReminder() {
        isSubtleReminderVisible = false
        operations.append(WindowOperation(timestamp: Date(), operation: .dismissSubtleReminder))
        onDismissSubtleReminder?()
    }
    
    func dismissAllReminders() {
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
        operations.append(WindowOperation(timestamp: Date(), operation: .dismissAllReminders))
        onDismissOverlayReminder?()
        onDismissSubtleReminder?()
    }
    
    func showSettings(settingsManager: any SettingsProviding, initialTab: Int) {
        operations.append(WindowOperation(timestamp: Date(), operation: .showSettings(initialTab: initialTab)))
        onShowSettings?(initialTab)
    }
    
    func showOnboarding(settingsManager: any SettingsProviding) {
        operations.append(WindowOperation(timestamp: Date(), operation: .showOnboarding))
        onShowOnboarding?()
    }
    
    // MARK: - Test Helpers
    
    /// Resets all state for a fresh test
    func reset() {
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
        operations.removeAll()
        onShowOverlayReminder = nil
        onShowSubtleReminder = nil
        onDismissOverlayReminder = nil
        onDismissSubtleReminder = nil
        onShowSettings = nil
        onShowOnboarding = nil
    }
    
    /// Returns the number of times a specific operation was performed
    func operationCount(_ operationType: WindowOperation.Operation) -> Int {
        operations.filter { operation in
            switch (operation.operation, operationType) {
            case (.showOverlayReminder, .showOverlayReminder),
                 (.showSubtleReminder, .showSubtleReminder),
                 (.dismissOverlayReminder, .dismissOverlayReminder),
                 (.dismissSubtleReminder, .dismissSubtleReminder),
                 (.dismissAllReminders, .dismissAllReminders),
                 (.showOnboarding, .showOnboarding):
                return true
            case (.showSettings(let tab1), .showSettings(let tab2)):
                return tab1 == tab2
            default:
                return false
            }
        }.count
    }
    
    /// Returns true if the operation was performed at least once
    func didPerformOperation(_ operationType: WindowOperation.Operation) -> Bool {
        operationCount(operationType) > 0
    }
    
    /// Returns the last operation performed, if any
    var lastOperation: WindowOperation? {
        operations.last
    }
}

// MARK: - Equatable Conformance for Testing

extension MockWindowManager.WindowOperation.Operation: Equatable {
    static func == (lhs: MockWindowManager.WindowOperation.Operation, rhs: MockWindowManager.WindowOperation.Operation) -> Bool {
        switch (lhs, rhs) {
        case (.showOverlayReminder, .showOverlayReminder),
             (.showSubtleReminder, .showSubtleReminder),
             (.dismissOverlayReminder, .dismissOverlayReminder),
             (.dismissSubtleReminder, .dismissSubtleReminder),
             (.dismissAllReminders, .dismissAllReminders),
             (.showOnboarding, .showOnboarding):
            return true
        case (.showSettings(let tab1), .showSettings(let tab2)):
            return tab1 == tab2
        default:
            return false
        }
    }
}
