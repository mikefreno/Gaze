//
//  AppDelegate.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var timerEngine: TimerEngine?
    private let settingsManager: SettingsManager = .shared
    private var updateManager: UpdateManager?
    private var overlayReminderWindowController: NSWindowController?
    private var subtleReminderWindowController: NSWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedTimers = false

    // Smart Mode services
    private var fullscreenService: FullscreenDetectionService?
    private var idleService: IdleMonitoringService?
    private var usageTrackingService: UsageTrackingService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)

        timerEngine = TimerEngine(settingsManager: settingsManager)

        setupSmartModeServices()

        // Initialize update manager after onboarding is complete
        if settingsManager.settings.hasCompletedOnboarding {
            updateManager = UpdateManager.shared
        }

        setupLifecycleObservers()

        observeSettingsChanges()

        if settingsManager.settings.hasCompletedOnboarding {
            startTimers()
        }
    }

    private func setupSmartModeServices() {
        fullscreenService = FullscreenDetectionService()
        idleService = IdleMonitoringService(
            idleThresholdMinutes: settingsManager.settings.smartMode.idleThresholdMinutes
        )
        usageTrackingService = UsageTrackingService(
            resetThresholdMinutes: settingsManager.settings.smartMode.usageResetAfterMinutes
        )

        if let idleService = idleService {
            usageTrackingService?.setupIdleMonitoring(idleService)
        }

        // Connect services to timer engine
        timerEngine?.setupSmartMode(
            fullscreenService: fullscreenService,
            idleService: idleService
        )

        // Observe smart mode settings changes
        settingsManager.$settings
            .map { $0.smartMode }
            .removeDuplicates()
            .sink { [weak self] smartMode in
                self?.idleService?.updateThreshold(minutes: smartMode.idleThresholdMinutes)
                self?.usageTrackingService?.updateResetThreshold(
                    minutes: smartMode.usageResetAfterMinutes)

                // Force state check when settings change to apply immediately
                self?.fullscreenService?.forceUpdate()
                self?.idleService?.forceUpdate()
            }
            .store(in: &cancellables)
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
        settingsManager.$settings
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
        settingsManager.saveImmediately()
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
        timerEngine?.handleSystemSleep()
        settingsManager.saveImmediately()
    }

    @objc private func systemDidWake() {
        timerEngine?.handleSystemWake()
    }

    private func observeReminderEvents() {
        timerEngine?.$activeReminder
            .sink { [weak self] reminder in
                guard let reminder = reminder else {
                    self?.dismissOverlayReminder()
                    return
                }
                self?.showReminder(reminder)
            }
            .store(in: &cancellables)
    }

    private func showReminder(_ event: ReminderEvent) {
        let contentView: AnyView
        let requiresFocus: Bool

        switch event {
        case .lookAwayTriggered(let countdownSeconds):
            contentView = AnyView(
                LookAwayReminderView(countdownSeconds: countdownSeconds) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
            requiresFocus = true
        case .blinkTriggered:
            let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
            contentView = AnyView(
                BlinkReminderView(sizePercentage: sizePercentage) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
            requiresFocus = false
        case .postureTriggered:
            let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
            contentView = AnyView(
                PostureReminderView(sizePercentage: sizePercentage) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
            )
            requiresFocus = false
        case .userTimerTriggered(let timer):
            if timer.type == .overlay {
                contentView = AnyView(
                    UserTimerOverlayReminderView(timer: timer) { [weak self] in
                        self?.timerEngine?.dismissReminder()
                    }
                )
                requiresFocus = true
            } else {
                let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
                contentView = AnyView(
                    UserTimerReminderView(timer: timer, sizePercentage: sizePercentage) {
                        [weak self] in
                        self?.timerEngine?.dismissReminder()
                    }
                )
                requiresFocus = false
            }
        }

        showReminderWindow(contentView, requiresFocus: requiresFocus, isOverlay: requiresFocus)
    }

    private func showReminderWindow(_ content: AnyView, requiresFocus: Bool, isOverlay: Bool) {
        guard let screen = NSScreen.main else { return }

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

        // Allow mouse events only for overlay reminders (they need dismiss button)
        // Subtle reminders should be completely transparent to mouse input
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

        // Track overlay and subtle reminders separately
        if isOverlay {
            overlayReminderWindowController?.close()
            overlayReminderWindowController = windowController
        } else {
            subtleReminderWindowController?.close()
            subtleReminderWindowController = windowController
        }
    }

    private func dismissOverlayReminder() {
        overlayReminderWindowController?.close()
        overlayReminderWindowController = nil
    }

    private func dismissSubtleReminder() {
        subtleReminderWindowController?.close()
        subtleReminderWindowController = nil
    }

    func openSettings(tab: Int = 0) {
        handleMenuDismissal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            SettingsWindowPresenter.shared.show(
                settingsManager: self.settingsManager, initialTab: tab)
        }
    }

    func openOnboarding() {
        handleMenuDismissal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            OnboardingWindowPresenter.shared.show(settingsManager: self.settingsManager)
        }
    }

    private func handleMenuDismissal() {
        NotificationCenter.default.post(name: Notification.Name("CloseMenuBarPopover"), object: nil)
        dismissOverlayReminder()
    }

}

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

class NonKeyWindow: NSWindow {
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}
