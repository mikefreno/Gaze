//
//  SystemSleepManager.swift
//  Gaze
//
//  Coordinates system sleep/wake handling.
//

import AppKit
import Foundation

@MainActor
final class SystemSleepManager {
    private let settingsManager: any SettingsProviding
    private weak var timerEngine: (any TimerEngineProviding)?
    private var observers: [NSObjectProtocol] = []

    init(timerEngine: (any TimerEngineProviding)?, settingsManager: any SettingsProviding) {
        self.timerEngine = timerEngine
        self.settingsManager = settingsManager
    }

    func startObserving() {
        guard observers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        let willSleep = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWillSleep()
        }

        let didWake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemDidWake()
        }

        observers = [willSleep, didWake]
    }

    func stopObserving() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func handleSystemWillSleep() {
        logInfo("System will sleep")
        timerEngine?.stop()
        settingsManager.saveImmediately()
    }

    private func handleSystemDidWake() {
        logInfo("System did wake")
        timerEngine?.start()
    }
}
