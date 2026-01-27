//
//  SmartModeCoordinator.swift
//  Gaze
//
//  Coordinates smart mode pause/resume behavior.
//

import Combine
import Foundation

protocol SmartModeCoordinatorDelegate: AnyObject {
    func smartModeDidRequestPauseAll(_ coordinator: SmartModeCoordinator, reason: PauseReason)
    func smartModeDidRequestResumeAll(_ coordinator: SmartModeCoordinator, reason: PauseReason)
}

@MainActor
final class SmartModeCoordinator {
    weak var delegate: SmartModeCoordinatorDelegate?

    private var fullscreenService: FullscreenDetectionService?
    private var idleService: IdleMonitoringService?
    private var cancellables = Set<AnyCancellable>()
    private var settingsProvider: (any SettingsProviding)?

    init() {}

    func setup(
        fullscreenService: FullscreenDetectionService?,
        idleService: IdleMonitoringService?,
        settingsProvider: any SettingsProviding
    ) {
        self.fullscreenService = fullscreenService
        self.idleService = idleService
        self.settingsProvider = settingsProvider

        fullscreenService?.$isFullscreenActive
            .sink { [weak self] isFullscreen in
                Task { @MainActor in
                    self?.handleFullscreenChange(isFullscreen: isFullscreen)
                }
            }
            .store(in: &cancellables)

        idleService?.$isIdle
            .sink { [weak self] isIdle in
                Task { @MainActor in
                    self?.handleIdleChange(isIdle: isIdle)
                }
            }
            .store(in: &cancellables)
    }

    func teardown() {
        cancellables.removeAll()
        fullscreenService = nil
        idleService = nil
        settingsProvider = nil
    }

    private func handleFullscreenChange(isFullscreen: Bool) {
        guard let settingsProvider else { return }
        guard settingsProvider.settings.smartMode.autoPauseOnFullscreen else { return }

        if isFullscreen {
            delegate?.smartModeDidRequestPauseAll(self, reason: .fullscreen)
            logInfo("⏸️ Timers paused: fullscreen detected")
        } else {
            delegate?.smartModeDidRequestResumeAll(self, reason: .fullscreen)
            logInfo("▶️ Timers resumed: fullscreen exited")
        }
    }

    private func handleIdleChange(isIdle: Bool) {
        guard let settingsProvider else { return }
        guard settingsProvider.settings.smartMode.autoPauseOnIdle else { return }

        if isIdle {
            delegate?.smartModeDidRequestPauseAll(self, reason: .idle)
            logInfo("⏸️ Timers paused: user idle")
        } else {
            delegate?.smartModeDidRequestResumeAll(self, reason: .idle)
            logInfo("▶️ Timers resumed: user active")
        }
    }
}
