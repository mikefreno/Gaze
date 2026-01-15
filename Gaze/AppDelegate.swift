//
//  AppDelegate.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import Combine
import SwiftUI
import os.log

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var timerEngine: TimerEngine?
    private let settingsManager: SettingsManager = .shared
    private let windowManager: WindowManaging
    private var updateManager: UpdateManager?
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedTimers = false
    
    // Logging manager
    private let logger = LoggingManager.shared

    // Smart Mode services
    private var fullscreenService: FullscreenDetectionService?
    private var idleService: IdleMonitoringService?
    private var usageTrackingService: UsageTrackingService?

    override init() {
        self.windowManager = WindowManager.shared
        super.init()
    }
    
    /// Initializer for testing with injectable dependencies
    init(windowManager: WindowManaging) {
        self.windowManager = windowManager
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Initialize logging
        logger.configureLogging()
        logger.appLogger.info("🚀 Application did finish launching")

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
        logger.appLogger.info("Starting timers")
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
        logger.appLogger.info(" applicationWill terminate")
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
        logger.systemLogger.info("System will sleep")
        timerEngine?.handleSystemSleep()
        settingsManager.saveImmediately()
    }

    @objc private func systemDidWake() {
        logger.systemLogger.info("System did wake")
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
                let view = UserTimerReminderView(timer: timer, sizePercentage: sizePercentage) { [weak self] in
                    self?.timerEngine?.dismissReminder()
                }
                windowManager.showReminderWindow(view, windowType: .subtle)
            }
        }
    }

    func openSettings(tab: Int = 0) {
        handleMenuDismissal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            windowManager.showSettings(settingsManager: self.settingsManager, initialTab: tab)
        }
    }

    func openOnboarding() {
        handleMenuDismissal()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            windowManager.showOnboarding(settingsManager: self.settingsManager)
        }
    }

    private func handleMenuDismissal() {
        NotificationCenter.default.post(name: Notification.Name("CloseMenuBarPopover"), object: nil)
        windowManager.dismissOverlayReminder()
    }

}
