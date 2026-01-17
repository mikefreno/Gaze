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
    private let serviceContainer: ServiceContainer
    private let windowManager: WindowManaging
    private var updateManager: UpdateManager?
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedTimers = false

    // Convenience accessor for settings
    private var settingsManager: any SettingsProviding {
        serviceContainer.settingsManager
    }

    override init() {
        self.serviceContainer = ServiceContainer.shared
        self.windowManager = WindowManager.shared
        super.init()

        // Setup window close observers
        setupWindowCloseObservers()
    }

    /// Initializer for testing with injectable dependencies
    init(serviceContainer: ServiceContainer, windowManager: WindowManaging) {
        self.serviceContainer = serviceContainer
        self.windowManager = windowManager
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)

        logInfo("🚀 Application did finish launching")

        timerEngine = serviceContainer.timerEngine

        serviceContainer.setupSmartModeServices()


        // Initialize update manager after onboarding is complete
        if settingsManager.settings.hasCompletedOnboarding {
            updateManager = UpdateManager.shared
        }

        setupLifecycleObservers()

        observeSettingsChanges()

        if settingsManager.settings.hasCompletedOnboarding {
            startTimers()
        }
        
        // DEBUG: Auto-start eye tracking test mode if launch argument is present
        #if DEBUG
        if CommandLine.arguments.contains("--debug-eye-tracking") {
            NSLog("🔬 DEBUG: Auto-starting eye tracking test mode")
            Task { @MainActor in
                // Enable enforce mode if not already
                if !settingsManager.settings.enforcementMode {
                    settingsManager.settings.enforcementMode = true
                }
                // Start test mode after a brief delay
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                NSLog("🔬 DEBUG: Starting test mode now...")
                await EnforceModeService.shared.startTestMode()
                NSLog("🔬 DEBUG: Test mode started")
            }
        }
        #endif
    }

    // Note: Smart mode setup is now handled by ServiceContainer
    // Keeping this method for settings change observation
    private func observeSmartModeSettings() {
        settingsManager.settingsPublisher
            .map { $0.smartMode }
            .removeDuplicates()
            .sink { [weak self] smartMode in
                guard let self = self else { return }
                self.serviceContainer.idleService?.updateThreshold(
                    minutes: smartMode.idleThresholdMinutes)
                self.serviceContainer.usageTrackingService?.updateResetThreshold(
                    minutes: smartMode.usageResetAfterMinutes)

                // Force state check when settings change to apply immediately
                self.serviceContainer.fullscreenService?.forceUpdate()
                self.serviceContainer.idleService?.forceUpdate()
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
        logInfo("Starting timers")
        timerEngine?.start()
        observeReminderEvents()
    }

    private func observeSettingsChanges() {
        settingsManager.settingsPublisher
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

        // Also observe smart mode settings
        observeSmartModeSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logInfo(" applicationWill terminate")
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
        logInfo("System will sleep")
        timerEngine?.handleSystemSleep()
        settingsManager.saveImmediately()
    }

    @objc private func systemDidWake() {
        logInfo("System did wake")
        timerEngine?.handleSystemWake()
    }

    private func observeReminderEvents() {
        timerEngine?.$activeReminder
            .sink { [weak self] reminder in
                guard let reminder = reminder else {
                    self?.windowManager.dismissOverlayReminder()
                    return
                }
                self?.showReminder(reminder)
            }
            .store(in: &cancellables)
    }

    private func showReminder(_ event: ReminderEvent) {
        switch event {
        case .lookAwayTriggered(let countdownSeconds):
            let view = LookAwayReminderView(countdownSeconds: countdownSeconds) { [weak self] in
                self?.timerEngine?.dismissReminder()
            }
            windowManager.showReminderWindow(view, windowType: .overlay)

        case .blinkTriggered:
            let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
            let view = BlinkReminderView(sizePercentage: sizePercentage) { [weak self] in
                self?.timerEngine?.dismissReminder()
            }
            windowManager.showReminderWindow(view, windowType: .subtle)

        case .postureTriggered:
            let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
            let view = PostureReminderView(sizePercentage: sizePercentage) { [weak self] in
                self?.timerEngine?.dismissReminder()
            }
            windowManager.showReminderWindow(view, windowType: .subtle)

        case .userTimerTriggered(let timer):
            if timer.type == .overlay {
                let view = UserTimerOverlayReminderView(timer: timer) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
                windowManager.showReminderWindow(view, windowType: .overlay)
            } else {
                let sizePercentage = settingsManager.settings.subtleReminderSize.percentage
                let view = UserTimerReminderView(timer: timer, sizePercentage: sizePercentage) {
                    [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
                windowManager.showReminderWindow(view, windowType: .subtle)
            }
        }
    }

    private let menuDismissalDelay: TimeInterval = 0.1

    func openSettings(tab: Int = 0) {
        performAfterMenuDismissal { [weak self] in
            guard let self else { return }
            self.windowManager.showSettings(settingsManager: self.settingsManager, initialTab: tab)
        }
    }

    func openOnboarding() {
        performAfterMenuDismissal { [weak self] in
            guard let self else { return }
            self.windowManager.showOnboarding(settingsManager: self.settingsManager)
        }
    }

    private func handleMenuDismissal() {
        NotificationCenter.default.post(name: Notification.Name("CloseMenuBarPopover"), object: nil)
        windowManager.dismissOverlayReminder()
    }

    private func performAfterMenuDismissal(_ action: @escaping () -> Void) {
        handleMenuDismissal()
        DispatchQueue.main.asyncAfter(deadline: .now() + menuDismissalDelay) {
            action()
        }
    }

    private func setupWindowCloseObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowDidClose),
            name: Notification.Name("SettingsWindowDidClose"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onboardingWindowDidClose),
            name: Notification.Name("OnboardingWindowDidClose"),
            object: nil
        )
    }

    @objc private func settingsWindowDidClose() {}

    @objc private func onboardingWindowDidClose() {}

}
