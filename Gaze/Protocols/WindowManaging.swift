//
//  WindowManaging.swift
//  Gaze
//
//  Protocol abstraction for window management to enable dependency injection and testing.
//

import AppKit
import SwiftUI

/// Represents the type of reminder window to display
enum ReminderWindowType {
    case overlay  // Full-screen, focus-stealing windows (lookAway, user timer overlays)
    case subtle   // Non-intrusive windows (blink, posture, user timer subtle)
}

/// Protocol that defines the interface for window management.
/// This abstraction allows for dependency injection and easy mocking in tests.
@MainActor
protocol WindowManaging: AnyObject {
    /// Shows a reminder window with the given content
    /// - Parameters:
    ///   - content: The SwiftUI view to display
    ///   - windowType: The type of reminder window
    func showReminderWindow<Content: View>(_ content: Content, windowType: ReminderWindowType)
    
    /// Dismisses the overlay reminder window
    func dismissOverlayReminder()
    
    /// Dismisses the subtle reminder window
    func dismissSubtleReminder()
    
    /// Dismisses all reminder windows
    func dismissAllReminders()
    
    /// Shows the settings window
    /// - Parameters:
    ///   - settingsManager: The settings manager to use
    ///   - initialTab: The initial tab to display
    func showSettings(settingsManager: any SettingsProviding, initialTab: Int)
    
    /// Shows the onboarding window
    /// - Parameter settingsManager: The settings manager to use
    func showOnboarding(settingsManager: any SettingsProviding)
    
    /// Whether an overlay reminder is currently visible
    var isOverlayReminderVisible: Bool { get }
    
    /// Whether a subtle reminder is currently visible
    var isSubtleReminderVisible: Bool { get }
}
