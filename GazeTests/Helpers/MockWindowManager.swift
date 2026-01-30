//
//  MockWindowManager.swift
//  GazeTests
//
//  Mock window manager for tests.
//

import Foundation
import SwiftUI
@testable import Gaze

@MainActor
final class MockWindowManager: WindowManaging {
    private(set) var didShowOnboarding = false
    private(set) var didShowSettings = false
    private(set) var didShowReminder = false
    private(set) var didDismissReminder = false

    var isOverlayReminderVisible: Bool = false
    var isSubtleReminderVisible: Bool = false

    func showOnboarding(settingsManager: any SettingsProviding) {
        didShowOnboarding = true
    }

    func showSettings(settingsManager: any SettingsProviding, initialTab: Int) {
        didShowSettings = true
    }

    func showReminderWindow<Content: View>(_ content: Content, windowType: ReminderWindowType) {
        didShowReminder = true
        switch windowType {
        case .overlay:
            isOverlayReminderVisible = true
        case .subtle:
            isSubtleReminderVisible = true
        }
    }

    func dismissOverlayReminder() {
        didDismissReminder = true
        isOverlayReminderVisible = false
    }

    func dismissSubtleReminder() {
        didDismissReminder = true
        isSubtleReminderVisible = false
    }

    func dismissAllReminders() {
        didDismissReminder = true
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
    }

    func reset() {
        didShowOnboarding = false
        didShowSettings = false
        didShowReminder = false
        didDismissReminder = false
        isOverlayReminderVisible = false
        isSubtleReminderVisible = false
    }
}
