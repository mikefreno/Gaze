//
//  EnforceModeService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import Combine
import Foundation

@MainActor
class EnforceModeService: ObservableObject {
    static let shared = EnforceModeService()
    
    @Published var isEnforceModeActive = false
    @Published var userCompliedWithBreak = false
    
    private var settingsManager: SettingsManager
    private var eyeTrackingService: EyeTrackingService
    private var timerEngine: TimerEngine?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.settingsManager = SettingsManager.shared
        self.eyeTrackingService = EyeTrackingService.shared
        setupObservers()
    }
    
    private func setupObservers() {
        eyeTrackingService.$userLookingAtScreen
            .sink { [weak self] lookingAtScreen in
                self?.handleGazeChange(lookingAtScreen: lookingAtScreen)
            }
            .store(in: &cancellables)
    }
    
    func enableEnforceMode() async {
        print("🔒 enableEnforceMode called")
        guard !isEnforceModeActive else {
            print("⚠️ Enforce mode already active")
            return
        }
        
        do {
            print("🔒 Starting eye tracking...")
            try await eyeTrackingService.startEyeTracking()
            isEnforceModeActive = true
            print("✓ Enforce mode enabled")
        } catch {
            print("⚠️ Failed to enable enforce mode: \(error.localizedDescription)")
            isEnforceModeActive = false
        }
    }
    
    func disableEnforceMode() {
        guard isEnforceModeActive else { return }
        
        eyeTrackingService.stopEyeTracking()
        isEnforceModeActive = false
        userCompliedWithBreak = false
        print("✓ Enforce mode disabled")
    }
    
    func setTimerEngine(_ engine: TimerEngine) {
        self.timerEngine = engine
    }
    
    func shouldEnforceBreak(for timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforceModeActive else { return false }
        guard settingsManager.settings.enforcementMode else { return false }
        
        switch timerIdentifier {
        case .builtIn(let type):
            return type == .lookAway
        case .user:
            return false
        }
    }
    
    func checkUserCompliance() {
        guard isEnforceModeActive else {
            userCompliedWithBreak = false
            return
        }
        
        let lookingAway = !eyeTrackingService.userLookingAtScreen
        userCompliedWithBreak = lookingAway
    }
    
    private func handleGazeChange(lookingAtScreen: Bool) {
        guard isEnforceModeActive else { return }
        
        checkUserCompliance()
    }
    
    func startEnforcementForActiveReminder() {
        guard let engine = timerEngine else { return }
        guard let activeReminder = engine.activeReminder else { return }
        
        switch activeReminder {
        case .lookAwayTriggered:
            if shouldEnforceBreak(for: .builtIn(.lookAway)) {
                checkUserCompliance()
            }
        default:
            break
        }
    }
}