//
//  WindowManager.swift
//  Gaze
//
//  Concrete implementation of WindowManaging for production use.
//

import AppKit
import SwiftUI

/// Production implementation of WindowManaging that creates real AppKit windows.
@MainActor
final class WindowManager: WindowManaging {
    static let shared = WindowManager()
    
    private var overlayReminderWindowController: NSWindowController?
    private var subtleReminderWindowController: NSWindowController?
    
    var isOverlayReminderVisible: Bool {
        overlayReminderWindowController?.window?.isVisible ?? false
    }
    
    var isSubtleReminderVisible: Bool {
        subtleReminderWindowController?.window?.isVisible ?? false
    }
    
    private init() {}
    
    func showReminderWindow<Content: View>(_ content: Content, windowType: ReminderWindowType) {
        guard let screen = NSScreen.main else { return }
        
        let requiresFocus = windowType == .overlay
        let window: NSWindow
        
        if requiresFocus {
            window = KeyableWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        } else {
            window = NonKeyWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        
        window.identifier = WindowIdentifiers.reminder
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: content)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = requiresFocus
        window.ignoresMouseEvents = !requiresFocus
        
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        
        if requiresFocus {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderFront(nil)
        }
        
        switch windowType {
        case .overlay:
            overlayReminderWindowController?.close()
            overlayReminderWindowController = windowController
        case .subtle:
            subtleReminderWindowController?.close()
            subtleReminderWindowController = windowController
        }
    }
    
    func dismissOverlayReminder() {
        overlayReminderWindowController?.close()
        overlayReminderWindowController = nil
    }
    
    func dismissSubtleReminder() {
        subtleReminderWindowController?.close()
        subtleReminderWindowController = nil
    }
    
    func dismissAllReminders() {
        dismissOverlayReminder()
        dismissSubtleReminder()
    }
    
    func showSettings(settingsManager: any SettingsProviding, initialTab: Int) {
        // Use the existing presenter for now
        if let realSettings = settingsManager as? SettingsManager {
            SettingsWindowPresenter.shared.show(settingsManager: realSettings, initialTab: initialTab)
        }
    }
    
    func showOnboarding(settingsManager: any SettingsProviding) {
        // Use the existing presenter for now
        if let realSettings = settingsManager as? SettingsManager {
            OnboardingWindowPresenter.shared.show(settingsManager: realSettings)
        }
    }
}
