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
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var timerEngine: TimerEngine?
    private var settingsManager: SettingsManager?
    private var reminderWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var timerStateBeforeSleep: [TimerType: Date] = [:]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsManager = SettingsManager.shared
        timerEngine = TimerEngine(settingsManager: settingsManager!)
        
        setupMenuBar()
        setupLifecycleObservers()
        
        // Start timers if onboarding is complete
        if settingsManager!.settings.hasCompletedOnboarding {
            timerEngine?.start()
            observeReminderEvents()
        }
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
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Gaze")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }
    
    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(
                timerEngine: timerEngine!,
                settingsManager: settingsManager!,
                onQuit: { NSApplication.shared.terminate(nil) }
            )
        )
        
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        
        self.popover = popover
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
        
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        
        reminderWindowController = windowController
    }
    
    private func dismissReminder() {
        reminderWindowController?.close()
        reminderWindowController = nil
    }
    
    // Public method to get menubar icon position for animations
    func getMenuBarIconPosition() -> NSRect? {
        return statusItem?.button?.window?.frame
    }
}
