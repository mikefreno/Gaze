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
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var timerEngine: TimerEngine?
    private var settingsManager: SettingsManager?
    private var updateManager: UpdateManager?
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
        
        // Initialize update manager after onboarding is complete
        if settingsManager!.settings.hasCompletedOnboarding {
            updateManager = UpdateManager.shared
        }
        
        // Detect App Store version asynchronously at launch
        Task {
            await settingsManager?.detectAppStoreVersion()
        }
        
        setupLifecycleObservers()
        observeSettingsChanges()
        
        // Start timers if onboarding is complete
        if settingsManager!.settings.hasCompletedOnboarding {
            startTimers()
        }
    }
    
    func onboardingCompleted() {
        startTimers()
        
        // Start update checks after onboarding
        if updateManager == nil {
            updateManager = UpdateManager.shared
        }
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
                if settings.hasCompletedOnboarding && self?.hasStartedTimers == false {
                    self?.startTimers()
                } else if self?.hasStartedTimers == true {
                    // Defer timer restart to next runloop to ensure settings are fully propagated
                    DispatchQueue.main.async {
                        self?.timerEngine?.start()
                    }
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
            let sizePercentage = settingsManager?.settings.subtleReminderSize.percentage ?? 5.0
            contentView = AnyView(
                BlinkReminderView(sizePercentage: sizePercentage) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
        case .postureTriggered:
            let sizePercentage = settingsManager?.settings.subtleReminderSize.percentage ?? 5.0
            contentView = AnyView(
                PostureReminderView(sizePercentage: sizePercentage) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
        }
        
        showReminderWindow(contentView)
    }
    
    private func showReminderWindow(_ content: AnyView) {
        guard let screen = NSScreen.main else { return }
        
        let window = KeyableWindow(
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
        NSApp.activate(ignoringOtherApps: true)
        
        reminderWindowController = windowController
    }
    
    private func dismissReminder() {
        reminderWindowController?.close()
        reminderWindowController = nil
    }
    
    // Public method to open settings window
    func openSettings(tab: Int = 0) {
        // Post notification to close menu bar popover
        NotificationCenter.default.post(name: Notification.Name("CloseMenuBarPopover"), object: nil)
        
        // Small delay to allow menu bar to close before opening settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.openSettingsWindow(tab: tab)
        }
    }
    
    // Public method to reopen onboarding window
    func openOnboarding() {
        // Post notification to close menu bar popover
        NotificationCenter.default.post(name: Notification.Name("CloseMenuBarPopover"), object: nil)
        
        // Small delay to allow menu bar to close before opening onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let settingsManager = self.settingsManager else { return }
            
            // Check if onboarding window already exists from the WindowGroup
            let existingWindow = NSApplication.shared.windows.first { window in
                // Check if window contains OnboardingContainerView by examining its content view
                if let hostingView = window.contentView as? NSHostingView<OnboardingContainerView> {
                    return true
                }
                // Also check for windows with our expected size (onboarding window dimensions)
                return window.frame.size.width == 700 && window.frame.size.height == 700 
                    && window.styleMask.contains(.titled)
                    && window.title.isEmpty  // WindowGroup windows have empty title by default
            }
            
            if let window = existingWindow {
                // Reuse existing window - just bring it to front
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                // Create new window matching WindowGroup style
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
                    styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                
                // Match the WindowGroup style: hiddenTitleBar
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.center()
                window.isReleasedWhenClosed = true
                window.contentView = NSHostingView(
                    rootView: OnboardingContainerView(settingsManager: settingsManager)
                )
                
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    private func openSettingsWindow(tab: Int) {
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
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
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
            self,
            selector: #selector(settingsWindowWillCloseNotification(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    @objc private func settingsWindowWillCloseNotification(_ notification: Notification) {
        settingsWindowController = nil
    }
}

// Custom window class that can become key to receive keyboard events
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
