//
//  SmartModeManager.swift
//  Gaze
//
//  Handles smart mode features like idle detection and fullscreen detection.
//

import Combine
import Foundation

@MainActor
class SmartModeManager {
    private var fullscreenService: FullscreenDetectionService?
    private var idleService: IdleMonitoringService?
    private var timerEngine: TimerEngine?
    
    private var cancellables = Set<AnyCancellable>()
    
    func setupSmartMode(
        timerEngine: TimerEngine,
        fullscreenService: FullscreenDetectionService?,
        idleService: IdleMonitoringService?
    ) {
        self.timerEngine = timerEngine
        self.fullscreenService = fullscreenService
        self.idleService = idleService
        
        // Subscribe to fullscreen state changes
        fullscreenService?.$isFullscreenActive
            .sink { [weak self] isFullscreen in
                Task { @MainActor in
                    self?.handleFullscreenChange(isFullscreen: isFullscreen)
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to idle state changes
        idleService?.$isIdle
            .sink { [weak self] isIdle in
                Task { @MainActor in
                    self?.handleIdleChange(isIdle: isIdle)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleFullscreenChange(isFullscreen: Bool) {
        guard let timerEngine = timerEngine else { return }
        guard timerEngine.settingsProviderForTesting.settings.smartMode.autoPauseOnFullscreen else { return }
        
        if isFullscreen {
            timerEngine.pauseAllTimers(reason: .fullscreen)
            logInfo("⏸️ Timers paused: fullscreen detected")
        } else {
            timerEngine.resumeAllTimers(reason: .fullscreen)
            logInfo("▶️ Timers resumed: fullscreen exited")
        }
    }
    
    private func handleIdleChange(isIdle: Bool) {
        guard let timerEngine = timerEngine else { return }
        guard timerEngine.settingsProviderForTesting.settings.smartMode.autoPauseOnIdle else { return }
        
        if isIdle {
            timerEngine.pauseAllTimers(reason: .idle)
            logInfo("⏸️ Timers paused: user idle")
        } else {
            timerEngine.resumeAllTimers(reason: .idle)
            logInfo("▶️ Timers resumed: user active")
        }
    }
}