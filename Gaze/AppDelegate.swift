//
//  AppDelegate.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI
import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var timerEngine: TimerEngine?
    private var settingsManager: SettingsManager?
    private var reminderWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var timerStateBeforeSleep: [TimerType: Date] = [:]
    private var hasStartedTimers = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
        
        settingsManager = SettingsManager.shared
        timerEngine = TimerEngine(settingsManager: settingsManager!)
        
        setupLifecycleObservers()
        observeSettingsChanges()
        
        // Start timers if onboarding is complete
        if settingsManager!.settings.hasCompletedOnboarding {
            startTimers()
        }
    }
    
    func onboardingCompleted() {
        startTimers()
    }
    
    private func startTimers() {
        guard !hasStartedTimers else { return }
        hasStartedTimers = true
        timerEngine?.start()
        observeReminderEvents()
    }
    
    private func observeSettingsChanges() {
        settingsManager?.$settings
            .sink { [weak self] settings in
                if settings.hasCompletedOnboarding {
                    self?.startTimers()
                } else if self?.hasStartedTimers == true {
                    // Restart timers when settings change (only if already started)
                    self?.timerEngine?.start()
                }
            }
            .store(in: &cancellables)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        settingsManager?.save()
        timerEngine?.stop()
    }
    
    private func setupLifecycleObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func systemWillSleep() {
        // Save timer states
        if let timerEngine = timerEngine {
            for (type, state) in timerEngine.timerStates {
                if state.isActive && !state.isPaused {
                    timerStateBeforeSleep[type] = Date()
                }
            }
        }
        timerEngine?.pause()
        settingsManager?.save()
    }
    
    @objc private func systemDidWake() {
        guard let timerEngine = timerEngine else { return }
        
        let now = Date()
        for (type, sleepTime) in timerStateBeforeSleep {
            let elapsed = Int(now.timeIntervalSince(sleepTime))
            
            if var state = timerEngine.timerStates[type] {
                state.remainingSeconds = max(0, state.remainingSeconds - elapsed)
                timerEngine.timerStates[type] = state
                
                // If timer expired during sleep, trigger it now
                if state.remainingSeconds <= 0 {
                    timerEngine.timerStates[type]?.remainingSeconds = 1
                }
            }
        }
        
        timerStateBeforeSleep.removeAll()
        timerEngine.resume()
    }
    
    private func observeReminderEvents() {
        timerEngine?.$activeReminder
            .sink { [weak self] reminder in
                guard let reminder = reminder else {
                    self?.dismissReminder()
                    return
                }
                self?.showReminder(reminder)
            }
            .store(in: &cancellables)
    }
    
    private func showReminder(_ event: ReminderEvent) {
        let contentView: AnyView
        
        switch event {
        case .lookAwayTriggered(let countdownSeconds):
            contentView = AnyView(
                LookAwayReminderView(countdownSeconds: countdownSeconds) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
        case .blinkTriggered:
            contentView = AnyView(
                BlinkReminderView { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
        case .postureTriggered:
            contentView = AnyView(
                PostureReminderView { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
        }
        
        showReminderWindow(contentView)
    }
    
private func showReminderWindow(_ content: AnyView) {
        guard let screen = NSScreen.main else { return }
        
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: content)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Ensure this window can receive key events
        window.acceptsMouseMovedEvents = true
        window.makeFirstResponder(window.contentView)
        
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        // Make sure the window is brought to front and made key for key events
        window.makeKeyAndOrderFront(nil)
        
        reminderWindowController = windowController
    }
    
    private func dismissReminder() {
        reminderWindowController?.close()
        reminderWindowController = nil
    }
    
    // Public method to open settings window
    func openSettings(tab: Int = 0) {
        // If window already exists, switch to the tab and bring it to front
        if let existingWindow = settingsWindowController?.window {
            NotificationCenter.default.post(
                name: Notification.Name("SwitchToSettingsTab"),
                object: tab
            )
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsWindowView(settingsManager: settingsManager!, initialTab: tab)
        )
        
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        
        settingsWindowController = windowController
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Observe when window is closed to clean up reference
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.settingsWindowController = nil
        }
    }
}